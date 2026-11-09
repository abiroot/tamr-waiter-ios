import Combine
import os
import SafariServices
import UIKit
import WebKit

/// Where the page is in loading: what a view shows over it. A struct, not an enum, so a new state
/// never breaks an app's `switch`.
public struct TamrPageState: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    /// The page is loading.
    public static let loading = TamrPageState(rawValue: "loading")
    /// The page is on screen (its first paint, or loaded).
    public static let loaded = TamrPageState(rawValue: "loaded")
    /// The page couldn't load (offline, DNS, TLS): `reload()`.
    public static let failed = TamrPageState(rawValue: "failed")
}

/// One Tamr waiter for one diner in one restaurant: the long-lived handle, with the Web SDK's
/// names. Show it with `TamrWaiterViewController` or `TamrWaiterView` as often as you like, and
/// `dispose()` it when the diner signs out. A hidden chat stays loaded until 10 minutes pass or
/// memory runs short.
@MainActor
public final class TamrWaiterController: ObservableObject {
    /// Loading, loaded or failed: what a view shows over the page.
    @Published public private(set) var pageState: TamrPageState = .loading

    /// Asked when the page wants the microphone for a voice note: ask the system
    /// (`AVAudioApplication.requestRecordPermission()`) and return the answer. Without it the chat
    /// is text only; the camera is always refused.
    public var onMicrophonePermission: (@MainActor () async -> Bool)?

    /// The page's first address (the launch in its fragment).
    public let url: URL
    /// Trace every message both ways and the page's own lines, and make the web view inspectable.
    public let debug: Bool

    private let onLog: (@MainActor (String) -> Void)?
    private let allowedOrigins: Set<String>
    private let chatPath: String
    private var bridge: Bridge!
    private var engine: (any WebViewDriving)?
    var makeEngine: (TamrWaiterController) -> any WebViewDriving = { WebKitHost(controller: $0) }
    private var identity: TamrIdentityProvider?
    private var cart: [String: TamrCartHandler] = [:]
    private var listeners: [String: [UUID: @MainActor (any PageMessage) -> Void]] = [:]
    private var closers: [(view: AnyObject, close: @MainActor () -> Void)] = []
    private weak var presenter: UIViewController?
    /// The open payment page's delegate: SFSafariViewController holds its delegate weakly.
    private var safariDelegate: SafariDelegate?
    private var preloaded = false
    private var disposed = false
    private var observers: [NSObjectProtocol] = []

    private static let logger = Logger(subsystem: "link.tamr.waiter", category: "TamrWaiter")

    /// A waiter for `restaurant` (`tamr.link/w/{restaurant}`) with the publishable `appKey`.
    /// `launch` signs the diner in on the first load; later, `setIdentityProvider`. `debug` prints
    /// `[tamr] …` lines to `onLog` or the system log and makes the web view inspectable; tokens,
    /// codes and what the diner types never print. Throws for a bad address, a key that isn't
    /// publishable, or a host that isn't an http(s) URL.
    public init(
        appKey: String,
        restaurant: String,
        branch: String? = nil,
        locale: String? = nil,
        appearance: Appearance? = nil,
        table: String? = nil,
        tableScan: String? = nil,
        mode: ServiceMode? = nil,
        launch: TamrIdentity? = nil,
        host: URL? = nil,
        debug: Bool = false,
        onLog: (@MainActor (String) -> Void)? = nil
    ) throws(TamrWaiterError) {
        let host = host ?? Address.tamr
        guard let origin = Address.origin(of: host) else {
            throw TamrWaiterError("host must be an http(s) URL")
        }
        url = try Address.shellURL(
            host: host, address: restaurant, key: appKey, branch: branch, locale: locale, appearance: appearance,
            launch: launch, table: table, tableScan: tableScan, mode: mode, debug: debug
        )
        allowedOrigins = [origin]
        chatPath = "/w/\(restaurant)"
        self.debug = debug
        self.onLog = onLog
        let first = url
        bridge = Bridge(
            surface: BridgeSurface(
                load: { [unowned self] url in
                    let engine = self.engine ?? makeEngine(self)
                    self.engine = engine
                    // After the web view exists: a view showing the chat moves it in on this.
                    pageState = .loading
                    engine.load(url)
                    // Loading hidden (a preload, or again after a release): parked in the
                    // key window, or iOS suspends the page until it is shown (#446).
                    if closers.isEmpty {
                        engine.park()
                    }
                },
                post: { [unowned self] json in
                    // Only into Tamr's page: a web view elsewhere never gets the bridge's messages.
                    if let engine, let current = engine.url, allowedOrigins.contains(Address.origin(of: current) ?? "") {
                        engine.deliver(json)
                    }
                },
                release: { [unowned self] in
                    engine?.detach()
                    engine = nil
                    if !disposed {
                        pageState = .loading
                    }
                },
                openPayment: { [unowned self] url, closed in openPayment(url, closed: closed) }
            ),
            url: { relaunch, branch in relaunch ? Address.relaunchURL(first, lastReadyBranch: branch) : first },
            capabilities: { [unowned self] in
                (identity == nil ? [] : ["identity"]) + (cart.isEmpty ? [] : ["cart"]) + ["visibility"]
                    + (onMicrophonePermission == nil ? [] : ["microphone"]) + (debug ? ["log"] : []) + ["orders", "pay"]
            },
            identity: { [unowned self] in identity },
            cart: { [unowned self] type in cart[type] },
            emit: { [unowned self] message in emit(message) },
            debug: debug,
            log: { [unowned self] line in write(line) },
            osVersion: UIDevice.current.systemVersion
        )
        let center = NotificationCenter.default
        observers = [
            // Back from the background or another app: a shown chat is told again (a payment's
            // status), and a released one preloads again.
            center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.becameActive() }
            },
            center.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.bridge.releaseIfHidden("released on a memory warning") }
            },
        ]
    }

    // MARK: - The app's side (the Web SDK's names)

    /// Who the diner is, asked whenever the page needs a fresh token. Nil, a throw or no answer
    /// within 15 seconds is no token.
    public func setIdentityProvider(_ provider: TamrIdentityProvider?) {
        let changed = (identity == nil) != (provider == nil)
        identity = provider
        if changed {
            bridge.hello()
        }
    }

    /// The waiter proposes lines for your cart ("Orders go to: the app's cart"): answer each line
    /// within 15 seconds.
    public func onCartAdd(_ handler: TamrCartHandler?) { setCart("cart.add", handler) }
    /// The diner changed a line the waiter added.
    public func onCartUpdate(_ handler: TamrCartHandler?) { setCart("cart.update", handler) }
    /// The diner removed a line the waiter added.
    public func onCartRemove(_ handler: TamrCartHandler?) { setCart("cart.remove", handler) }

    /// Every page event of a bridge type (`ready`, `order.placed`, `payment.completed`, `close`…).
    /// Returns the function that removes it, on the main actor like everything here.
    @discardableResult
    public func on(
        _ type: String, _ listener: @escaping @MainActor (any PageMessage) -> Void
    ) -> @MainActor () -> Void {
        let id = UUID()
        listeners[type, default: [:]][id] = listener
        return { [weak self] in
            _ = self?.listeners[type]?.removeValue(forKey: id)
        }
    }

    /// The page's language (a BCP 47 tag): kept and sent again whenever the page loads.
    public func setLocale(_ locale: String) { bridge.keep(LocaleMessage(data: LocaleData(locale: locale))) }
    /// Your app's colours and what shows; laid over what you set before.
    public func setAppearance(_ appearance: Appearance) { bridge.keep(AppearanceMessage(data: appearance)) }
    /// Your wording for the waiter's name, welcome and labels.
    public func setText(_ text: Text) { bridge.keep(TextMessage(data: text)) }
    /// Your app's colour scheme.
    public func setTheme(_ scheme: ThemeScheme) { bridge.keep(ThemeMessage(data: ThemeData(scheme: scheme))) }
    /// Where the diner is: branch, table, service mode, currency.
    public func setContext(_ context: ContextData) { bridge.keep(ContextMessage(data: context)) }
    /// The welcome screen's suggestions; an empty list brings the restaurant's own back.
    public func setStarters(_ starters: [Starter]) { bridge.keep(StartersMessage(data: StartersData(items: starters))) }
    /// Allergens and diets every reply respects; they only ever tighten what the restaurant set.
    public func setRestrictions(_ restrictions: RestrictionsData) { bridge.keep(RestrictionsMessage(data: restrictions)) }
    /// Your cart, so the waiter's matches it.
    public func sendCart(_ lines: [SnapshotLine]) { bridge.send(CartSnapshotMessage(data: CartSnapshotData(lines: lines))) }
    /// Sends `text` as the diner's message, as if they typed it.
    public func sendMessage(_ text: String) { bridge.send(ChatSendMessage(data: ChatSendData(text: text))) }
    /// Starts a new conversation.
    public func newChat() { bridge.send(ChatNewMessage()) }
    /// Signs the diner out of the page (your app signed them out).
    public func clearIdentity() { bridge.send(IdentityClearMessage()) }
    /// Any other message from the contract, held until the page is ready.
    public func send(_ message: any HostMessage) { bridge.send(message) }

    /// Load the chat hidden so it opens at once: on the menu screen, not at app start. It loads
    /// again when your app comes back after a release. Does nothing while loaded.
    public func preload() {
        guard !disposed else { return }
        preloaded = true
        bridge.load()
    }

    /// Load the page again, after `.failed`.
    public func reload() {
        bridge.reload()
    }

    /// Unload the chat and stop every callback, for good: call it when the diner signs out.
    public func dispose() {
        guard !disposed else { return }
        disposed = true
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        listeners.removeAll()
        closers.removeAll()
        bridge.dispose()
    }

    // MARK: - The views' side

    /// The web view showing this chat, made and loaded here when nothing loaded it yet.
    func webView() -> WKWebView? {
        bridge.load()
        engine?.unpark()
        return (engine as? WebKitHost)?.webView
    }

    /// `view` began to show the chat.
    func viewShown(by view: UIViewController, close: @escaping @MainActor () -> Void) {
        guard !disposed else { return }
        presenter = view
        closers.removeAll { $0.view === view }
        closers.append((view, close))
        bridge.load()
        bridge.setShown(true)
    }

    /// `view` stopped showing the chat: it stays loaded, hidden, for the next open.
    func viewHidden(by view: UIViewController) {
        closers.removeAll { $0.view === view }
        guard !disposed, closers.isEmpty else { return }
        bridge.setShown(false)
        // Out of the view, back to the key window: hidden, but not suspended (#446).
        engine?.park()
        if pageState == .failed {
            // It loads again on the next open.
            bridge.releaseIfHidden("the page failed and the chat was closed")
        }
    }

    // MARK: - The web view's side (WebKitHost, and the tests' fake)

    func trace(_ line: String) {
        bridge.trace(line)
    }

    /// One message from the page: only the main frame on Tamr's origin counts.
    func pageMessage(_ json: String, isMainFrame: Bool, origin: String?) {
        guard isMainFrame, let origin, allowedOrigins.contains(origin) else {
            trace("<- a message from another frame or origin: ignored")
            return
        }
        bridge.receive(json)
    }

    /// Whether the web view loads `url`; anything that opens outside the app is opened here.
    func navigate(to url: URL, isMainFrame: Bool) -> Bool {
        let decision = Address.decide(url, isMainFrame: isMainFrame, allowedOrigins: allowedOrigins, chatPath: chatPath)
        switch decision {
        case .allow:
            return true
        case .openExternally:
            if !disposed {
                UIApplication.shared.open(url)
            }
        case .block:
            trace("blocked \(Self.redacted(url))")
        }
        return false
    }

    func pageStarted(_ url: URL?) {
        guard !disposed else { return }
        trace("page started \(Self.redacted(url))")
        bridge.documentStarted()
    }

    func pageFinished(_ url: URL?) {
        guard !disposed else { return }
        trace("page finished \(Self.redacted(url))")
        if pageState == .loading {
            pageState = .loaded
        }
        bridge.documentLoaded()
    }

    /// Only the chat failing counts: a refused link or a replaced load also fails.
    func pageFailed(_ error: any Error) {
        let error = error as NSError
        let failing = error.userInfo[NSURLErrorFailingURLErrorKey] as? URL
        trace("load error \(error.code) \(error.domain) (\(Self.redacted(failing)))")
        let ours = failing.map { allowedOrigins.contains(Address.origin(of: $0) ?? "") } ?? true
        guard !disposed, ours, !(error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled) else { return }
        if bridge.isShown {
            pageState = .failed
        } else {
            // It loads again on the next open or preload.
            bridge.releaseIfHidden("the page failed while hidden")
        }
    }

    /// iOS ended the page's process: a shown chat loads again, a hidden one waits.
    func processEnded() {
        guard !disposed else { return }
        trace("the web process ended")
        if bridge.isShown {
            bridge.reload()
        } else {
            bridge.releaseIfHidden("released: the web process ended while hidden")
        }
    }

    /// Only a microphone-only request from Tamr's page, and only when the app says yes.
    func allowsMicrophone(origin: String?, microphoneOnly: Bool) async -> Bool {
        guard !disposed, microphoneOnly, let origin, allowedOrigins.contains(origin),
              let ask = onMicrophonePermission
        else { return false }
        return await ask()
    }

    // MARK: - Private

    private func setCart(_ type: String, _ handler: TamrCartHandler?) {
        let had = !cart.isEmpty
        cart[type] = handler
        if had != !cart.isEmpty {
            bridge.hello()
        }
    }

    private func emit(_ message: any PageMessage) {
        if message is PaintedMessage, pageState == .loading {
            pageState = .loaded
        }
        if message is CloseMessage {
            if let close = closers.last?.close {
                close()
            } else {
                trace("close, but nothing to close")
            }
        }
        for listener in listeners[message.type]?.values.map({ $0 }) ?? [] {
            listener(message)
        }
    }

    private func becameActive() {
        bridge.resumed()
        if preloaded, !bridge.isLoaded {
            bridge.load()
        }
    }

    /// `payment.open`: SFSafariViewController over the chat, never the web view (ADR 0007).
    private func openPayment(_ url: URL, closed: @escaping @MainActor () -> Void) -> Bool {
        guard let from = Self.topmost(presenter) else { return false }
        let safari = SFSafariViewController(url: url)
        let delegate = SafariDelegate { [weak self] in
            self?.safariDelegate = nil
            closed()
        }
        safariDelegate = delegate
        safari.delegate = delegate
        from.present(safari, animated: true)
        return true
    }

    private func write(_ line: String) {
        if let onLog {
            onLog(line)
        } else {
            Self.logger.info("\(line, privacy: .public)")
        }
    }

    /// A URL for a debug line: its query and fragment (the key, a launch) cut (debug.md).
    static func redacted(_ url: URL?) -> String {
        guard let url else { return "" }
        return url.absoluteString.components(separatedBy: CharacterSet(charactersIn: "?#"))[0]
    }

    private static func topmost(_ view: UIViewController?) -> UIViewController? {
        var top = view ?? UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

/// Tells the bridge when the diner closes the payment's page.
@MainActor
private final class SafariDelegate: NSObject, @preconcurrency SFSafariViewControllerDelegate {
    let closed: @MainActor () -> Void

    init(closed: @escaping @MainActor () -> Void) {
        self.closed = closed
    }

    func safariViewControllerDidFinish(_: SFSafariViewController) {
        closed()
    }
}
