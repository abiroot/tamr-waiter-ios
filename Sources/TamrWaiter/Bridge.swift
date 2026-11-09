import Foundation

/// Who the diner is: a token the app's backend signed (five minutes, used once), or a launch code
/// from `POST /api/v1/sdk/launch-codes`. These are the only two forms a launch takes (ADR 0008), so
/// the enum is closed for good.
public enum TamrIdentity: Sendable, Equatable {
    case token(String)
    case code(String)
}

/// A value the SDK can't use: a bad restaurant address, a key that isn't publishable, or a token
/// and a code together.
public struct TamrWaiterError: Error, Sendable, Equatable, CustomStringConvertible {
    public let description: String

    init(_ description: String) {
        self.description = "Tamr: \(description)"
    }
}

/// Who the diner is, asked whenever the page needs a fresh token. Nil is "no one".
public typealias TamrIdentityProvider = @MainActor (IdentityRequestReason) async throws -> TamrIdentity?

/// The app's answer to the waiter's cart change, line by line.
public typealias TamrCartHandler = @MainActor (CartChange) async throws -> Reply

/// What the bridge drives: the web view, through closures, so its rules are tested without one.
@MainActor
struct BridgeSurface {
    /// Load (or load again) the page.
    var load: (URL) -> Void
    /// Deliver one envelope to the page.
    var post: (String) -> Void
    /// Give the web view back; the next load builds a new one.
    var release: () -> Void
    /// Open a payment's page in the in-app browser: false when it couldn't. `closed` runs when the
    /// diner closes it.
    var openPayment: (URL, _ closed: @escaping @MainActor () -> Void) -> Bool
}

/// One chat's bridge (ADR 0005, 0006): the handshake, messages held until `ready`, what the app
/// set, the page's requests and its events. Policy (tokens, retries) lives in the page. The rules
/// are the Web, Flutter and React Native SDKs', with #608's review fixes.
@MainActor
final class Bridge {
    /// The longest `log` line the page may send (the contract's `log`).
    private static let logMax = 2000
    /// Messages held before `ready`; past this the oldest go first.
    private static let outboxLimit = 100

    private let surface: BridgeSurface
    private let url: (_ relaunch: Bool, _ lastBranch: String?) -> URL
    private let capabilities: () -> [String]
    private let identity: () -> TamrIdentityProvider?
    private let cart: (String) -> TamrCartHandler?
    private let emit: (any PageMessage) -> Void
    private let debug: Bool
    private let log: (String) -> Void
    private let replyTimeout: Duration
    private let idleRelease: Duration
    private let osVersion: String?

    private(set) var isLoaded = false
    private(set) var isShown = false
    private var released = false
    private var ready = false
    private var disposed = false
    private var shownAt: Int?
    /// Every hello sent to this document: the page answers each one.
    private var hellos = Set<String>()
    private var lastBranch: String?
    private var idle: Task<Void, Never>?
    private var outbox: [String] = []
    private var kept: [String: any HostMessage] = [:]
    private var keptOrder: [String] = []
    private var seen = Set<String>()
    private var seenOrder: [String] = []

    init(
        surface: BridgeSurface,
        url: @escaping (_ relaunch: Bool, _ lastBranch: String?) -> URL,
        capabilities: @escaping () -> [String],
        identity: @escaping () -> TamrIdentityProvider?,
        cart: @escaping (String) -> TamrCartHandler?,
        emit: @escaping (any PageMessage) -> Void,
        debug: Bool,
        log: @escaping (String) -> Void,
        osVersion: String? = nil,
        replyTimeout: Duration = .milliseconds(TamrContract.replyTimeoutMs),
        idleRelease: Duration = .seconds(600)
    ) {
        self.surface = surface
        self.url = url
        self.capabilities = capabilities
        self.identity = identity
        self.cart = cart
        self.emit = emit
        self.debug = debug
        self.log = log
        self.osVersion = osVersion
        self.replyTimeout = replyTimeout
        self.idleRelease = idleRelease
    }

    /// Load the page if it isn't loaded.
    func load() {
        guard !isLoaded, !disposed else { return }
        isLoaded = true
        ready = false
        surface.load(url(released, lastBranch))
        trace(released ? "load (again, after a release)" : "load")
        scheduleRelease()
    }

    /// A new document started: it answers only its own hellos. Held messages stay: they go out on
    /// its ready.
    func documentStarted() {
        guard !disposed else { return }
        ready = false
        hellos.removeAll()
    }

    /// The document finished loading: it listens, so say hello.
    func documentLoaded() {
        guard !disposed, isLoaded, !ready else { return }
        sayHello()
    }

    /// Say hello again, as when what the app handles changed.
    func hello() {
        if isLoaded, !disposed {
            sayHello()
        }
    }

    /// One message from the page's handler (main frame, Tamr's origin: the host checked both).
    func receive(_ raw: String) {
        guard !disposed else { return }
        guard let parsed = parsePageMessage(raw) else {
            trace("<- a message that doesn't parse: ignored")
            return
        }
        guard seen.insert(parsed.id).inserted else { return }
        seenOrder.append(parsed.id)
        if seenOrder.count > TamrContract.dedupeWindow {
            seen.remove(seenOrder.removeFirst())
        }
        let message = parsed.message
        if !(message is LogMessage) {
            trace("<- \(message.type)")
        }
        switch message {
        case let ready as ReadyMessage:
            guard let replyTo = parsed.replyTo, hellos.contains(replyTo) else {
                // The page answered its own wait, or loaded again on its own: not ready until it
                // answers a new hello, whose ready re-sends what the app set (ADR 0005, #578).
                self.ready = false
                sayHello()
                return
            }
            // The answer to another hello on this document (the app changed what it handles).
            if self.ready {
                return
            }
            onReady(ready.data)
        case let request as IdentityRequestMessage:
            Task { await onIdentityRequest(request.data.reason) }
        case let add as CartAddMessage:
            Task { await onCart(parsed.id, add.type, add.data) }
        case let update as CartUpdateMessage:
            Task { await onCart(parsed.id, update.type, update.data) }
        case let remove as CartRemoveMessage:
            Task { await onCart(parsed.id, remove.type, remove.data) }
        case let payment as PaymentOpenMessage:
            onPaymentOpen(parsed.id, payment.data.url)
        case let line as LogMessage:
            // Over 2,000 characters is the page's bug: dropped, never cut (debug.md).
            if line.data.message.count > Self.logMax {
                trace("<- log over 2,000 characters: ignored")
            } else if debug {
                log("[tamr] page \(line.data.level.rawValue): \(line.data.message)")
            }
        default:
            break
        }
        emit(message)
    }

    /// A one-off message (`chat.send`, `cart.snapshot`…): held until `ready`.
    func send(_ message: any HostMessage) {
        guard !disposed, let raw = encode(message, id: newId()) else { return }
        if ready {
            surface.post(raw)
            return
        }
        outbox.append(raw)
        if outbox.count > Self.outboxLimit {
            outbox.removeFirst()
        }
        trace("-> \(message.type) held until the chat is ready")
    }

    /// A setting the page needs after every `ready` (theme, locale…): the latest of each type is
    /// kept.
    func keep(_ message: any HostMessage) {
        guard !disposed else { return }
        if kept.updateValue(message, forKey: message.type) == nil {
            keptOrder.append(message.type)
        }
        if ready {
            post(message)
        }
    }

    /// The chat is on screen or not.
    func setShown(_ shown: Bool) {
        guard !disposed, shown != isShown else { return }
        isShown = shown
        shownAt = shown ? now() : nil
        if ready {
            post(visibility())
        }
        trace(shown ? "shown" : "hidden")
        scheduleRelease()
    }

    /// The app came back, or the payment's browser closed: a shown chat is told again, so the page
    /// reads a payment's status.
    func resumed() {
        guard !disposed, isShown, ready else { return }
        shownAt = now()
        post(visibility())
    }

    /// Give the web view back (memory warning, a dead web process), unless the chat is shown.
    func releaseIfHidden(_ why: String) {
        guard !isShown, isLoaded, !disposed else { return }
        release(why)
    }

    /// Load the page again (after a failure), without the spent launch.
    func reload() {
        guard !disposed else { return }
        if isLoaded {
            release("reload")
        }
        load()
    }

    /// Stop for good: nothing is sent or called after this.
    func dispose() {
        guard !disposed else { return }
        disposed = true
        idle?.cancel()
        outbox.removeAll()
        surface.release()
    }

    /// One line of the shell's own trace.
    func trace(_ line: String) {
        if debug {
            log("[tamr] shell: \(line)")
        }
    }

    // MARK: - Private

    private func sayHello() {
        let hello = HostHelloData(
            sdk: TamrWaiterSDK.version, platform: .ios, osVersion: osVersion, capabilities: capabilities()
        )
        if let id = post(HostHelloMessage(data: hello)) {
            hellos.insert(id)
        }
        trace("-> host.hello")
    }

    private func onReady(_ data: ReadyData) {
        ready = true
        lastBranch = data.branch ?? lastBranch
        // What the app set goes again after every load (ADR 0005), then what waited.
        for type in keptOrder {
            if let message = kept[type] {
                post(message)
            }
        }
        post(visibility())
        let waiting = outbox
        outbox.removeAll()
        waiting.forEach(surface.post)
        trace("ready, \(waiting.count) held messages sent")
    }

    private func visibility() -> VisibilityMessage {
        let at = isShown ? shownAt : nil
        shownAt = nil
        return VisibilityMessage(data: VisibilityData(shown: isShown, at: at))
    }

    private func onIdentityRequest(_ reason: IdentityRequestReason) async {
        guard let provider = identity() else {
            trace("the page asked for the diner's identity and no identity provider is set: a live key needs setIdentityProvider")
            return
        }
        let answer: TamrIdentity? = await within(fallback: nil) { try await provider(reason) }
        guard let answer, !disposed else {
            trace("identity provider gave nothing")
            return
        }
        switch answer {
        case let .token(token): post(IdentityTokenMessage(data: IdentityTokenData(token: token)))
        case let .code(code): post(IdentityTokenMessage(data: IdentityTokenData(code: code)))
        }
        trace("-> identity.token")
    }

    private func onCart(_ id: String, _ type: String, _ change: CartChange) async {
        let answer: Reply
        if let handler = cart(type) {
            answer = await within(fallback: Self.error(.failed)) { try await handler(change) }
        } else {
            answer = Self.error(.unsupported)
        }
        reply(to: id, answer)
    }

    private func onPaymentOpen(_ id: String, _ link: String) {
        guard let url = URL(string: link), url.scheme?.lowercased() == "https", url.host?.isEmpty == false else {
            trace("payment.open refused: not an https link")
            reply(to: id, Self.error(.notAllowed))
            return
        }
        // SFSafariViewController is in the app, so the app never leaves the foreground: the page is
        // told again when the diner closes it (Ayman's adjustment 1 on #446).
        let opened = surface.openPayment(url) { [weak self] in self?.resumed() }
        if !opened {
            trace("payment.open: the in-app browser didn't open")
        }
        reply(to: id, opened ? Reply(ok: true) : Self.error(.failed, "The in-app browser didn't open."))
    }

    private func reply(to id: String, _ answer: Reply) {
        if !disposed {
            post(HostReplyMessage(data: answer), replyTo: id)
        }
    }

    /// The app's answer, or `fallback` after 15 s, a throw or nothing.
    private func within<T: Sendable>(
        fallback: T, _ work: @escaping @MainActor () async throws -> T?
    ) async -> T {
        let once = Once<T>()
        let timeout = replyTimeout
        return await withCheckedContinuation { continuation in
            once.continuation = continuation
            let job = Task { @MainActor in
                let value = try? await work()
                once.finish(value.flatMap { $0 } ?? fallback)
            }
            Task { @MainActor in
                try? await Task.sleep(for: timeout)
                job.cancel()
                once.finish(fallback)
            }
        }
    }

    private func scheduleRelease() {
        idle?.cancel()
        idle = nil
        guard !isShown, isLoaded, !disposed else { return }
        let delay = idleRelease
        idle = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            self.idle = nil
            self.release("released after 10 minutes hidden")
        }
    }

    private func release(_ why: String) {
        idle?.cancel()
        idle = nil
        surface.release()
        isLoaded = false
        released = true
        ready = false
        hellos.removeAll()
        // What the app sends while released goes to the next load's ready.
        trace(why)
    }

    @discardableResult
    private func post(_ message: any HostMessage, replyTo: String? = nil) -> String? {
        let id = newId()
        guard let raw = encode(message, id: id, replyTo: replyTo) else { return nil }
        surface.post(raw)
        return id
    }

    private func encode(_ message: any HostMessage, id: String, replyTo: String? = nil) -> String? {
        do {
            return try encodeHostMessage(message, id: id, ts: now(), replyTo: replyTo)
        } catch {
            trace("-> \(message.type) couldn't be encoded: dropped")
            return nil
        }
    }

    private func now() -> Int {
        Int(Date().timeIntervalSince1970 * 1000)
    }

    private func newId() -> String {
        UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
    }

    private static func error(_ code: ReplyErrorCode, _ message: String? = nil) -> Reply {
        Reply(ok: false, error: ReplyError(code: code, message: message))
    }
}

/// Resumes a continuation once: the first of the app's answer and the timeout wins.
@MainActor
private final class Once<T: Sendable> {
    var continuation: CheckedContinuation<T, Never>?

    func finish(_ value: T) {
        continuation?.resume(returning: value)
        continuation = nil
    }
}
