@testable import TamrWaiter
import XCTest

/// A bridge over a fake web view that records what it is asked to do.
@MainActor
final class BridgeHarness {
    struct Posted {
        let id: String
        let type: String
        let data: [String: Any]
        let replyTo: String?
    }

    var raw: [String] = []
    var loads: [URL] = []
    var releases = 0
    var payments: [URL] = []
    var closePayment: (@MainActor () -> Void)?
    var opens = true
    var emitted: [String] = []
    var logs: [String] = []
    var identity: TamrIdentityProvider?
    var cart: TamrCartHandler?
    private var pageIds = 0
    private(set) var bridge: Bridge!

    static let page = URL(string: "https://tamr.link/w/cedar-house")!

    init(debug: Bool = false, replyTimeout: Duration = .seconds(15), idleRelease: Duration = .seconds(600)) {
        bridge = Bridge(
            surface: BridgeSurface(
                load: { [unowned self] in loads.append($0) },
                post: { [unowned self] in raw.append($0) },
                release: { [unowned self] in releases += 1 },
                openPayment: { [unowned self] url, closed in
                    payments.append(url)
                    closePayment = closed
                    return opens
                }
            ),
            url: { relaunch, branch in
                relaunch ? URL(string: "https://tamr.link/again/\(branch ?? "none")")! : Self.page
            },
            capabilities: { ["visibility", "orders", "pay"] },
            identity: { [unowned self] in identity },
            cart: { [unowned self] _ in cart },
            emit: { [unowned self] in emitted.append($0.type) },
            debug: debug,
            log: { [unowned self] in logs.append($0) },
            osVersion: "26.0",
            replyTimeout: replyTimeout,
            idleRelease: idleRelease
        )
    }

    var posted: [Posted] {
        raw.compactMap { text in
            guard let object = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else { return nil }
            return Posted(
                id: object["id"] as? String ?? "",
                type: object["type"] as? String ?? "",
                data: object["data"] as? [String: Any] ?? [:],
                replyTo: object["replyTo"] as? String
            )
        }
    }

    var types: [String] { posted.map(\.type) }
    var hellos: [Posted] { posted.filter { $0.type == "host.hello" } }

    /// One message from the page.
    func fromPage(_ type: String, _ data: [String: Any] = [:], replyTo: String? = nil, id: String? = nil) {
        pageIds += 1
        var envelope: [String: Any] = ["v": 1, "id": id ?? "p\(pageIds)", "type": type, "ts": 1, "data": data]
        if let replyTo {
            envelope["replyTo"] = replyTo
        }
        let json = try! JSONSerialization.data(withJSONObject: envelope)
        bridge.receive(String(decoding: json, as: UTF8.self))
    }

    /// The page's ready, answering `replyTo` (the latest hello by default).
    func ready(replyTo: String? = nil, branch: String? = "achrafieh", unsolicited: Bool = false) {
        let data: [String: Any] = [
            "org": "cedar-house", "branch": branch ?? NSNull(), "conversationId": NSNull(), "capabilities": [],
        ]
        fromPage("ready", data, replyTo: unsolicited ? nil : (replyTo ?? hellos.last?.id))
    }

    /// Load, the document starts and loads, and the page answers the hello.
    func open(branch: String? = "achrafieh") {
        bridge.load()
        bridge.documentStarted()
        bridge.documentLoaded()
        ready(branch: branch)
    }
}

/// Lets the bridge's tasks run.
@MainActor
func settle(_ times: Int = 5) async {
    for _ in 0..<times {
        await Task.yield()
    }
}

@MainActor
final class BridgeTests: XCTestCase {
    func testLoadsOnceAndSaysHelloWhenTheDocumentHasLoaded() {
        let h = BridgeHarness()
        h.bridge.load()
        h.bridge.load()
        XCTAssertEqual(h.loads, [BridgeHarness.page])
        XCTAssertEqual(h.types, [])
        h.bridge.documentStarted()
        h.bridge.documentLoaded()
        XCTAssertEqual(h.types, ["host.hello"])
        let hello = h.hellos[0].data
        XCTAssertEqual(hello["platform"] as? String, "ios")
        XCTAssertEqual(hello["sdk"] as? String, TamrWaiterSDK.version)
        XCTAssertEqual(hello["osVersion"] as? String, "26.0")
        XCTAssertEqual(hello["capabilities"] as? [String], ["visibility", "orders", "pay"])
    }

    func testSaysHelloAgainOnAReadyThatIsNotItsReply() {
        let h = BridgeHarness()
        h.bridge.load()
        h.bridge.documentStarted()
        h.bridge.documentLoaded()
        h.ready(unsolicited: true)
        XCTAssertEqual(h.types, ["host.hello", "host.hello"])
        h.ready()
        XCTAssertEqual(h.types, ["host.hello", "host.hello", "visibility"])
    }

    /// #608's review 1.
    func testSettlesTwoHellosInFlightAcceptingEachReadyOnce() {
        let h = BridgeHarness()
        h.bridge.keep(LocaleMessage(data: LocaleData(locale: "ar")))
        h.bridge.load()
        h.bridge.documentStarted()
        h.bridge.documentLoaded()
        h.bridge.hello()
        let (first, second) = (h.hellos[0].id, h.hellos[1].id)
        h.ready(replyTo: first)
        h.ready(replyTo: second)
        XCTAssertEqual(h.types, ["host.hello", "host.hello", "locale", "visibility"])
    }

    /// #608's review 2: the page loads again on its own, and gets what the app set again.
    func testReSendsWhatTheAppSetWhenThePageLoadsAgainOnItsOwn() {
        let h = BridgeHarness()
        h.bridge.keep(ThemeMessage(data: ThemeData(scheme: .dark)))
        h.open()
        let before = h.types.count
        h.ready(unsolicited: true)
        XCTAssertEqual(Array(h.types[before...]), ["host.hello"])
        h.ready()
        XCTAssertEqual(Array(h.types[before...]), ["host.hello", "theme", "visibility"])
    }

    /// #608's review 2: held messages survive the first load, a reload and a release.
    func testKeepsWhatTheAppSentBeforeTheFirstLoadAcrossAReloadAndARelease() {
        let h = BridgeHarness()
        h.bridge.send(ChatSendMessage(data: ChatSendData(text: "A table for two?")))
        h.bridge.load()
        h.bridge.documentStarted()
        h.bridge.documentLoaded()
        h.bridge.reload()
        h.bridge.documentStarted()
        h.bridge.documentLoaded()
        h.ready()
        XCTAssertEqual(h.types.last, "chat.send")
        XCTAssertEqual(h.posted.last?.data["text"] as? String, "A table for two?")
        h.bridge.releaseIfHidden("memory")
        h.bridge.send(ChatNewMessage())
        h.bridge.load()
        h.bridge.documentStarted()
        h.bridge.documentLoaded()
        XCTAssertNotEqual(h.types.last, "chat.new")
        h.ready()
        XCTAssertEqual(h.types.last, "chat.new")
    }

    func testSendsWhatTheAppSetAfterEveryReadyAndChangesAtOnceWhileReady() {
        let h = BridgeHarness()
        h.bridge.keep(LocaleMessage(data: LocaleData(locale: "fr")))
        h.bridge.keep(LocaleMessage(data: LocaleData(locale: "ar")))
        h.open()
        XCTAssertEqual(h.posted.filter { $0.type == "locale" }.map { $0.data["locale"] as? String }, ["ar"])
        h.bridge.keep(ThemeMessage(data: ThemeData(scheme: .light)))
        XCTAssertEqual(h.types.last, "theme")
    }

    func testTakesEachMessageOnce() {
        let h = BridgeHarness()
        h.open()
        h.fromPage("close", id: "same")
        h.fromPage("close", id: "same")
        XCTAssertEqual(h.emitted.filter { $0 == "close" }.count, 1)
    }

    func testAnswersIdentityRequestWithTheProvidersTokenAsyncIncluded() async {
        let h = BridgeHarness()
        h.identity = { _ in
            try await Task.sleep(for: .milliseconds(5))
            return .token("aaaa.bbbb.cccc")
        }
        h.open()
        h.fromPage("identity.request", ["reason": "first_open"])
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(h.types.last, "identity.token")
        XCTAssertEqual(h.posted.last?.data["token"] as? String, "aaaa.bbbb.cccc")
    }

    func testSendsNothingForAProviderThatHangsThrowsOrGivesNothingAndSaysSoWithoutOne() async {
        let h = BridgeHarness(debug: true, replyTimeout: .milliseconds(20))
        h.open()
        let before = h.types.count
        h.fromPage("identity.request", ["reason": "expired"])
        await settle()
        XCTAssertTrue(h.logs.contains { $0.contains("no identity provider is set") })
        h.identity = { _ in
            try await Task.sleep(for: .seconds(60))
            return .code("late")
        }
        h.fromPage("identity.request", ["reason": "expired"])
        h.identity = { _ in throw CancellationError() }
        h.fromPage("identity.request", ["reason": "expired"])
        h.identity = { _ in nil }
        h.fromPage("identity.request", ["reason": "expired"])
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(h.types.count, before)
    }

    func testAnswersACartChangeWithTheAppsReplyOrUnsupportedOrFailedAfterTheTimeout() async {
        let h = BridgeHarness(replyTimeout: .milliseconds(20))
        h.open()
        let change: [String: Any] = ["lines": [], "origin": "waiter", "conversationId": "c1"]
        h.fromPage("cart.add", change, id: "add-1")
        await settle()
        XCTAssertEqual(h.posted.last?.replyTo, "add-1")
        XCTAssertEqual((h.posted.last?.data["error"] as? [String: Any])?["code"] as? String, "unsupported")

        h.cart = { _ in Reply(ok: true) }
        h.fromPage("cart.update", change, id: "update-1")
        try? await Task.sleep(for: .milliseconds(10))
        XCTAssertEqual(h.posted.last?.replyTo, "update-1")
        XCTAssertEqual(h.posted.last?.data["ok"] as? Bool, true)

        h.cart = { _ in
            try await Task.sleep(for: .seconds(60))
            return Reply(ok: true)
        }
        h.fromPage("cart.remove", change, id: "remove-1")
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(h.posted.last?.replyTo, "remove-1")
        XCTAssertEqual((h.posted.last?.data["error"] as? [String: Any])?["code"] as? String, "failed")
    }

    /// #604, and Ayman's adjustment 1 on #446.
    func testOpensPaymentOpenHttpsInTheInAppBrowserRefusesAnythingElseAndTellsTheChatAgainWhenItCloses() {
        let h = BridgeHarness()
        h.open()
        h.bridge.setShown(true)
        h.fromPage("payment.open", ["paymentId": "pay_1", "url": "http://pay.example/1"], id: "pay-http")
        XCTAssertEqual(h.payments, [])
        XCTAssertEqual(h.posted.last?.replyTo, "pay-http")
        XCTAssertEqual((h.posted.last?.data["error"] as? [String: Any])?["code"] as? String, "not_allowed")

        h.fromPage("payment.open", ["paymentId": "pay_1", "url": "https://pay.example/1"], id: "pay-https")
        XCTAssertEqual(h.payments, [URL(string: "https://pay.example/1")!])
        XCTAssertEqual(h.posted.last?.replyTo, "pay-https")
        XCTAssertEqual(h.posted.last?.data["ok"] as? Bool, true)
        // SFSafariViewController is in the app: closing it is the only sign the diner is back.
        h.closePayment?()
        XCTAssertEqual(h.types.last, "visibility")
        XCTAssertEqual(h.posted.last?.data["shown"] as? Bool, true)
    }

    func testAnswersAnErrorWhenTheBrowserDoesNotOpen() {
        let h = BridgeHarness()
        h.opens = false
        h.open()
        h.fromPage("payment.open", ["paymentId": "pay_1", "url": "https://pay.example/1"], id: "pay")
        XCTAssertEqual((h.posted.last?.data["error"] as? [String: Any])?["code"] as? String, "failed")
    }

    func testTellsThePageWhenShownAndAgainWhenTheAppResumesOnlyThen() {
        let h = BridgeHarness()
        h.open()
        h.bridge.setShown(true)
        XCTAssertEqual(h.posted.last?.data["shown"] as? Bool, true)
        XCTAssertNotNil(h.posted.last?.data["at"])
        let before = h.types.count
        h.bridge.resumed()
        XCTAssertEqual(Array(h.types[before...]), ["visibility"])
        h.bridge.setShown(false)
        XCTAssertEqual(h.posted.last?.data["shown"] as? Bool, false)
        let hidden = h.types.count
        h.bridge.resumed()
        XCTAssertEqual(h.types.count, hidden)
    }

    func testReleasesAHiddenChatAfterTheIdleTimeAndRelaunchesOnTheLastBranchNeverWhileShown() async {
        let h = BridgeHarness(idleRelease: .milliseconds(20))
        h.open(branch: "hamra")
        try? await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(h.releases, 1)
        h.bridge.load()
        XCTAssertEqual(h.loads.last, URL(string: "https://tamr.link/again/hamra"))
        h.bridge.setShown(true)
        try? await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(h.releases, 1)
        h.bridge.releaseIfHidden("memory")
        XCTAssertEqual(h.releases, 1)
    }

    func testStopsAfterDispose() {
        let h = BridgeHarness()
        h.open()
        h.bridge.dispose()
        let before = h.raw.count
        h.bridge.send(ChatNewMessage())
        h.fromPage("close")
        h.bridge.load()
        XCTAssertEqual(h.raw.count, before)
        XCTAssertEqual(h.emitted.filter { $0 == "close" }.count, 0)
    }
}
