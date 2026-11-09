@testable import TamrWaiter
import UIKit
import XCTest

/// A web view that records what the controller asks of it.
@MainActor
final class FakeEngine: WebViewDriving {
    var url: URL?
    var loads: [URL] = []
    var delivered: [String] = []
    var detached = false
    var parks = 0
    var unparks = 0

    func load(_ url: URL) {
        self.url = url
        loads.append(url)
    }

    func deliver(_ json: String) {
        delivered.append(json)
    }

    func detach() {
        detached = true
    }

    func park() {
        parks += 1
    }

    func unpark() {
        unparks += 1
    }

    var types: [String] {
        delivered.compactMap {
            (try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any])?["type"] as? String
        }
    }

    var lastHello: String? {
        delivered.compactMap { text -> String? in
            guard let object = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
                  object["type"] as? String == "host.hello" else { return nil }
            return object["id"] as? String
        }.last
    }
}

@MainActor
final class ControllerTests: XCTestCase {
    private let tamr = "https://tamr.link"
    private var engines: [FakeEngine] = []

    private func waiter(debug: Bool = false) throws -> TamrWaiterController {
        let controller = try TamrWaiterController(
            appKey: "tamr_pk_test_abababababababab", restaurant: "cedar-house", launch: .token("aaaa.bbbb.cccc"),
            debug: debug, onLog: { _ in }
        )
        controller.makeEngine = { [unowned self] _ in
            let engine = FakeEngine()
            engines.append(engine)
            return engine
        }
        return controller
    }

    private func message(_ type: String, _ data: [String: Any] = [:], replyTo: String? = nil, id: String = UUID().uuidString) -> String {
        var envelope: [String: Any] = ["v": 1, "id": id, "type": type, "ts": 1, "data": data]
        envelope["replyTo"] = replyTo
        return String(decoding: try! JSONSerialization.data(withJSONObject: envelope), as: UTF8.self)
    }

    /// The page loads and answers the hello.
    private func ready(_ controller: TamrWaiterController) throws {
        let engine = try XCTUnwrap(engines.last)
        controller.pageStarted(engine.url)
        controller.pageFinished(engine.url)
        let data: [String: Any] = ["org": "cedar-house", "branch": NSNull(), "conversationId": NSNull(), "capabilities": []]
        controller.pageMessage(message("ready", data, replyTo: engine.lastHello), isMainFrame: true, origin: tamr)
    }

    func testInitThrowsForABadAddressKeyOrHost() {
        XCTAssertThrowsError(try TamrWaiterController(appKey: "tamr_pk_test_abababababababab", restaurant: "Cedar House"))
        XCTAssertThrowsError(try TamrWaiterController(appKey: "sk_live_secret", restaurant: "cedar-house"))
        XCTAssertThrowsError(try TamrWaiterController(
            appKey: "tamr_pk_test_abababababababab", restaurant: "cedar-house", host: URL(string: "ftp://tamr.link")!
        ))
    }

    func testPreloadLoadsTheShellsAddressOnceInOneWebView() throws {
        let controller = try waiter()
        controller.preload()
        controller.preload()
        XCTAssertEqual(engines.count, 1)
        let url = try XCTUnwrap(engines[0].loads.first)
        XCTAssertEqual(engines[0].loads.count, 1)
        XCTAssertTrue(url.absoluteString.hasPrefix("https://tamr.link/w/cedar-house?key=tamr_pk_test_abababababababab#token=aaaa.bbbb.cccc&embed=ios"))
        XCTAssertEqual(controller.pageState, .loading)
        try ready(controller)
        XCTAssertEqual(controller.pageState, .loaded)
        XCTAssertEqual(engines[0].types.first, "host.hello")
    }

    func testTakesMessagesOnlyFromTheMainFrameOnTamrsOriginAndDeliversOnlyThere() throws {
        let controller = try waiter()
        var closes = 0
        controller.on("close") { _ in closes += 1 }
        controller.preload()
        try ready(controller)
        controller.pageMessage(message("close"), isMainFrame: false, origin: tamr)
        controller.pageMessage(message("close"), isMainFrame: true, origin: "https://evil.example")
        XCTAssertEqual(closes, 0)
        controller.pageMessage(message("close"), isMainFrame: true, origin: tamr)
        XCTAssertEqual(closes, 1)

        let engine = engines[0]
        let before = engine.delivered.count
        engine.url = URL(string: "https://evil.example/")
        controller.setTheme(.dark)
        XCTAssertEqual(engine.delivered.count, before)
        engine.url = URL(string: "\(tamr)/w/cedar-house")
        controller.setTheme(.light)
        XCTAssertEqual(engine.types.last, "theme")
    }

    func testARemovedListenerNoLongerFires() throws {
        let controller = try waiter()
        var heard: [String] = []
        let remove = controller.on("close") { _ in heard.append("first") }
        controller.on("close") { _ in heard.append("second") }
        controller.preload()
        try ready(controller)
        controller.pageMessage(message("close"), isMainFrame: true, origin: tamr)
        XCTAssertEqual(heard.sorted(), ["first", "second"])
        remove()
        remove()
        controller.pageMessage(message("close"), isMainFrame: true, origin: tamr)
        XCTAssertEqual(heard.sorted(), ["first", "second", "second"])
    }

    func testClosesTheViewShowingItOnThePagesClose() throws {
        let controller = try waiter()
        let view = UIViewController()
        var closed = 0
        controller.viewShown(by: view) { closed += 1 }
        try ready(controller)
        controller.pageMessage(message("close"), isMainFrame: true, origin: tamr)
        XCTAssertEqual(closed, 1)
        controller.viewHidden(by: view)
        controller.pageMessage(message("close"), isMainFrame: true, origin: tamr)
        XCTAssertEqual(closed, 1)
    }

    /// #446: on an iPhone, a web view in no window is suspended while it waits, so a hidden chat
    /// is parked in the key window, and a view takes it back out.
    func testParksAHiddenChatAndUnparksItForTheViewShowingIt() throws {
        let controller = try waiter()
        controller.preload()
        XCTAssertEqual(engines[0].parks, 1)
        let view = UIViewController()
        controller.viewShown(by: view) {}
        _ = controller.webView()
        XCTAssertEqual(engines[0].unparks, 1)
        controller.viewHidden(by: view)
        XCTAssertEqual(engines[0].parks, 2)
        controller.dispose()
    }

    func testDoesNotParkAChatLoadedForAViewShowingIt() throws {
        let controller = try waiter()
        let view = UIViewController()
        controller.viewShown(by: view) {}
        XCTAssertEqual(engines.count, 1)
        XCTAssertEqual(engines[0].parks, 0)
        // A second view closing while the first still shows it: still not parked.
        let other = UIViewController()
        controller.viewShown(by: other) {}
        controller.viewHidden(by: other)
        XCTAssertEqual(engines[0].parks, 0)
        controller.viewHidden(by: view)
        XCTAssertEqual(engines[0].parks, 1)
        controller.dispose()
    }

    func testAReleasedChatLoadsAgainParked() throws {
        let controller = try waiter()
        controller.preload()
        try ready(controller)
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertEqual(engines.count, 2)
        XCTAssertEqual(engines[1].parks, 1)
        controller.dispose()
    }

    /// The real web view: with no key window (a test runs in no app), it waits in no window as
    /// before, and unparking gives back what parking turned off.
    func testTheWebViewWaitsInNoWindowWithoutAKeyWindowAndUnparksToItsDefaults() throws {
        let controller = try waiter()
        let host = WebKitHost(controller: controller)
        host.park()
        XCTAssertNil(host.webView.superview)
        host.webView.isUserInteractionEnabled = false
        host.webView.accessibilityElementsHidden = true
        host.webView.scrollView.scrollsToTop = false
        host.unpark()
        XCTAssertTrue(host.webView.isUserInteractionEnabled)
        XCTAssertFalse(host.webView.accessibilityElementsHidden)
        XCTAssertTrue(host.webView.scrollView.scrollsToTop)
        controller.dispose()
    }

    func testTellsAShownChatAgainWhenTheAppBecomesActive() throws {
        let controller = try waiter()
        let view = UIViewController()
        controller.viewShown(by: view) {}
        try ready(controller)
        let before = engines[0].types.count
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertEqual(Array(engines[0].types[before...]), ["visibility"])
        controller.viewHidden(by: view)
        let hidden = engines[0].types.count
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertEqual(engines[0].types.count, hidden)
        controller.dispose()
    }

    func testReleasesAHiddenChatOnAMemoryWarningAndPreloadsItAgainWhenTheAppComesBack() throws {
        let controller = try waiter()
        controller.preload()
        try ready(controller)
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        XCTAssertTrue(engines[0].detached)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertEqual(engines.count, 2)
        // Without the spent launch.
        XCTAssertFalse(try XCTUnwrap(engines[1].loads.first).absoluteString.contains("token="))
        controller.dispose()
    }

    func testAShownChatSurvivesAMemoryWarningAndReloadsWhenItsProcessEnds() throws {
        let controller = try waiter()
        controller.viewShown(by: UIViewController()) {}
        try ready(controller)
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        XCTAssertFalse(engines[0].detached)
        controller.processEnded()
        XCTAssertTrue(engines[0].detached)
        XCTAssertEqual(engines.count, 2)
        controller.dispose()
    }

    func testAHiddenChatGoesColdWhenItsProcessEnds() throws {
        let controller = try waiter()
        controller.preload()
        try ready(controller)
        controller.processEnded()
        XCTAssertTrue(engines[0].detached)
        XCTAssertEqual(engines.count, 1)
    }

    func testShowsARetryWhenThePageFailsWhileShownButNotForACancelledLoadOrAnotherSite() throws {
        let controller = try waiter()
        controller.viewShown(by: UIViewController()) {}
        let page = URL(string: "\(tamr)/w/cedar-house")!
        controller.pageFailed(NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled, userInfo: [NSURLErrorFailingURLErrorKey: page]))
        controller.pageFailed(NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: [
            NSURLErrorFailingURLErrorKey: URL(string: "https://elsewhere.example/")!,
        ]))
        XCTAssertEqual(controller.pageState, .loading)
        controller.pageFailed(NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: [NSURLErrorFailingURLErrorKey: page]))
        XCTAssertEqual(controller.pageState, .failed)
        controller.reload()
        XCTAssertEqual(engines.count, 2)
        XCTAssertEqual(controller.pageState, .loading)
    }

    func testKeepsTheWebViewOnTheWaiterPage() throws {
        let controller = try waiter()
        XCTAssertTrue(controller.navigate(to: URL(string: "\(tamr)/w/cedar-house?key=x")!, isMainFrame: true))
        XCTAssertFalse(controller.navigate(to: URL(string: "javascript:alert(1)")!, isMainFrame: true))
        XCTAssertFalse(controller.navigate(to: URL(string: "data:text/html,hi")!, isMainFrame: true))
        XCTAssertFalse(controller.navigate(to: URL(string: "\(tamr)/w/cedar-house")!, isMainFrame: false))
    }

    func testAnnouncesTheMicrophoneOnlyWithAPermissionCallbackAndGrantsItOnlyForTamrsMicrophoneOnlyRequest() async throws {
        let controller = try waiter()
        controller.preload()
        controller.pageFinished(engines[0].url)
        XCTAssertFalse(engines[0].delivered.last?.contains("\"microphone\"") ?? true)
        let granted = await controller.allowsMicrophone(origin: tamr, microphoneOnly: true)
        XCTAssertFalse(granted, "no callback: text only")

        var asked = 0
        controller.onMicrophonePermission = {
            asked += 1
            return true
        }
        let ours = await controller.allowsMicrophone(origin: tamr, microphoneOnly: true)
        let camera = await controller.allowsMicrophone(origin: tamr, microphoneOnly: false)
        let elsewhere = await controller.allowsMicrophone(origin: "https://evil.example", microphoneOnly: true)
        let noOrigin = await controller.allowsMicrophone(origin: nil, microphoneOnly: true)
        XCTAssertEqual([ours, camera, elsewhere, noOrigin], [true, false, false, false])
        XCTAssertEqual(asked, 1, "the camera and other origins never reach the app")
    }

    func testSaysHelloAgainWhenTheAppStartsOrStopsHandlingIdentityOrTheCart() throws {
        let controller = try waiter()
        controller.preload()
        try ready(controller)
        let hellos = { self.engines[0].types.filter { $0 == "host.hello" }.count }
        let before = hellos()
        controller.setIdentityProvider { _ in .token("t") }
        controller.setIdentityProvider { _ in .token("u") }
        controller.onCartAdd { _ in Reply(ok: true) }
        controller.onCartUpdate { _ in Reply(ok: true) }
        XCTAssertEqual(hellos(), before + 2)
        XCTAssertTrue(engines[0].delivered.last?.contains("\"cart\"") ?? false)
    }
}
