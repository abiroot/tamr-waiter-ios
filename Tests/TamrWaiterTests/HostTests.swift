@testable import TamrWaiter
import XCTest

/// What every shell implements on the host side (`host_v1.json`, ADR 0007): navigation, origins,
/// the waiter page's address and the relaunch address; and the debug lines (`debug_v1.json`).
final class HostTests: XCTestCase {
    func testNavigation() throws {
        let navigation = try XCTUnwrap(try fixture("host_v1")["navigation"] as? [String: Any])
        let allowed = Set(try XCTUnwrap(navigation["allowedOrigins"] as? [String]))
        let chatPath = try XCTUnwrap(navigation["chatPath"] as? String)
        let cases = try XCTUnwrap(navigation["cases"] as? [[String: Any]])
        XCTAssertFalse(cases.isEmpty)
        for c in cases {
            let url = try XCTUnwrap(URL(string: try XCTUnwrap(c["url"] as? String)))
            let isMainFrame = try XCTUnwrap(c["isMainFrame"] as? Bool)
            let decision = Address.decide(url, isMainFrame: isMainFrame, allowedOrigins: allowed, chatPath: chatPath)
            XCTAssertEqual(decision.rawValue, c["expect"] as? String, "\(url) (main frame: \(isMainFrame))")
        }
    }

    func testOrigins() throws {
        for c in try XCTUnwrap(try fixture("host_v1")["origins"] as? [[String: Any]]) {
            let url = try XCTUnwrap(URL(string: try XCTUnwrap(c["url"] as? String)))
            XCTAssertEqual(Address.origin(of: url), c["expect"] as? String, "\(url)")
        }
    }

    func testWaiterURL() throws {
        for c in try XCTUnwrap(try fixture("host_v1")["waiterUrl"] as? [[String: Any]]) {
            let host = try XCTUnwrap(URL(string: try XCTUnwrap(c["origin"] as? String)))
            let address = try XCTUnwrap(c["address"] as? String)
            let query = (c["query"] as? [String: String] ?? [:]).mapValues { Optional($0) }
            let fragment = (c["fragment"] as? [String: String] ?? [:]).mapValues { Optional($0) }
            let comment = c["$comment"] as? String ?? ""
            if c["expect"] as? String == "error" {
                XCTAssertThrowsError(try Address.waiterURL(host: host, address: address, query: query, fragment: fragment), comment)
            } else {
                let url = try Address.waiterURL(host: host, address: address, query: query, fragment: fragment)
                XCTAssertEqual(url.absoluteString, c["expect"] as? String, comment)
            }
        }
    }

    func testRelaunchURL() throws {
        for c in try XCTUnwrap(try fixture("host_v1")["relaunchUrl"] as? [[String: Any]]) {
            let url = try XCTUnwrap(URL(string: try XCTUnwrap(c["url"] as? String)))
            let again = Address.relaunchURL(url, lastReadyBranch: c["lastReadyBranch"] as? String)
            XCTAssertEqual(again.absoluteString, c["expect"] as? String, c["$comment"] as? String ?? "")
        }
    }

    func testShellURL() throws {
        let url = try Address.shellURL(
            host: Address.tamr, address: "cedar-house", key: "tamr_pk_test_abababababababab",
            branch: nil, locale: "ar", appearance: Appearance(accent: .set("#1F7A4D"), showBack: .reset),
            launch: .token("aaaa.bbbb.cccc"), table: nil, tableScan: nil, mode: .dineIn, debug: true
        )
        let parts = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(parts.path, "/w/cedar-house")
        XCTAssertEqual(parts.queryItems?.map(\.name), ["key", "lang", "appearance"])
        XCTAssertEqual(parts.fragment, "token=aaaa.bbbb.cccc&embed=ios&sdk=\(TamrWaiterSDK.version)&mode=dine_in&debug=1")
        // The set fields only, as base64url JSON: a reset never rides on the address.
        let encoded = try XCTUnwrap(parts.queryItems?.last?.value)
        var base64 = encoded.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        let json = try XCTUnwrap(Data(base64Encoded: base64))
        XCTAssertEqual(String(data: json, encoding: .utf8), ##"{"accent":"#1F7A4D"}"##)

        XCTAssertThrowsError(try Address.shellURL(
            host: Address.tamr, address: "cedar-house", key: "sk_live_secret", branch: nil, locale: nil,
            appearance: nil, launch: nil, table: nil, tableScan: nil, mode: nil, debug: false
        ))
    }

    func testDebugLines() async throws {
        let debug = try fixture("debug_v1")
        let printed = try XCTUnwrap(debug["printed"] as? [[String: Any]])
        let rejected = debug["rejected"] as? [[String: Any]] ?? []
        let harness = await BridgeHarness(debug: true)
        for c in printed {
            let message = try JSONSerialization.data(withJSONObject: try XCTUnwrap(c["message"]))
            await harness.bridge.receive(String(decoding: message, as: UTF8.self))
        }
        let lines = await harness.logs.filter { $0.hasPrefix("[tamr] page ") }
        XCTAssertEqual(lines, printed.compactMap { $0["line"] as? String })
        for c in rejected {
            let message = try JSONSerialization.data(withJSONObject: c)
            await harness.bridge.receive(String(decoding: message, as: UTF8.self))
        }
        let after = await harness.logs.filter { $0.hasPrefix("[tamr] page ") }
        XCTAssertEqual(after, lines, "a rejected log prints nothing")
    }
}
