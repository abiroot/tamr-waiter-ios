import Foundation

/// What the chat's web view does with a navigation (ADR 0007, as `host_v1.json` states it case by
/// case).
enum TamrNavigation: String {
    /// The waiter page: load it in the web view.
    case allow
    /// Any other web, phone or mail link: open it outside the app.
    case openExternally
    /// A frame or script loading anything else, `javascript:` and `data:` included: refuse it.
    case block
}

/// The addresses a shell builds and the navigation it allows (`host_v1.json`).
enum Address {
    static let tamr = URL(string: "https://tamr.link")!

    private static let linkSchemes: Set<String> = ["https", "http", "tel", "mailto"]

    /// `scheme://host[:port]`, lower case, without the default port. Nil for anything but an
    /// http(s) URL with a host.
    static func origin(of url: URL) -> String? {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = parts.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = parts.host, !host.isEmpty
        else { return nil }
        return origin(scheme: scheme, host: host, port: parts.port)
    }

    /// WebKit's `WKSecurityOrigin` parts: port 0 is the scheme's default.
    static func origin(scheme: String, host: String, port: Int?) -> String? {
        let scheme = scheme.lowercased()
        guard scheme == "https" || scheme == "http", !host.isEmpty else { return nil }
        let standard = scheme == "https" ? 443 : 80
        let suffix = port.map { $0 == 0 || $0 == standard ? "" : ":\($0)" } ?? ""
        return "\(scheme)://\(host.lowercased())\(suffix)"
    }

    /// The web view stays on `chatPath` (`/w/{address}`) and below it, in the main frame, on
    /// `allowedOrigins`. A new window (not the main frame) never replaces the chat, even with the
    /// chat's own address: a web link from any frame opens outside the app instead.
    static func decide(
        _ url: URL, isMainFrame: Bool, allowedOrigins: Set<String>, chatPath: String
    ) -> TamrNavigation {
        let scheme = url.scheme?.lowercased() ?? ""
        if scheme == "about" {
            return .allow
        }
        let root = chatPath.replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
        let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? ""
        if isMainFrame, let origin = origin(of: url), allowedOrigins.contains(origin),
           path == root || path.hasPrefix(root + "/")
        {
            return .allow
        }
        if linkSchemes.contains(scheme) {
            return .openExternally
        }
        if !isMainFrame || scheme == "javascript" || scheme == "data" {
            return .block
        }
        return .openExternally
    }

    private static let addressPattern = try! NSRegularExpression(pattern: "^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$")
    private static let keyPattern = try! NSRegularExpression(pattern: "^tamr_pk_(?:test|live)_[A-Za-z0-9]{16,64}$")

    /// `{host}/w/{address}?{query}#{fragment}`: what the server renders in the query, the rest in
    /// the fragment, which no server sees; each in the contract's order. Throws for a bad address,
    /// or a token and a code together.
    static func waiterURL(
        host: URL, address: String, query: [String: String?], fragment: [String: String?]
    ) throws(TamrWaiterError) -> URL {
        guard matches(addressPattern, address) else {
            throw TamrWaiterError("\"\(address)\" isn't a waiter address")
        }
        if fragment["token"].flatMap({ $0 }) != nil, fragment["code"].flatMap({ $0 }) != nil {
            throw TamrWaiterError("a launch is a token or a code, not both")
        }
        var base = host.absoluteString
        while base.hasSuffix("/") {
            base.removeLast()
        }
        return build(
            "\(base)/w/\(address)",
            encode(query, order: TamrContract.queryKeys),
            encode(fragment, order: TamrContract.fragmentKeys)
        )
    }

    /// `waiterURL` for this shell (`embed=ios`). Throws for a key that isn't publishable.
    static func shellURL(
        host: URL, address: String, key: String, branch: String?, locale: String?,
        appearance: Appearance?, launch: TamrIdentity?, table: String?, tableScan: String?,
        mode: ServiceMode?, debug: Bool
    ) throws(TamrWaiterError) -> URL {
        guard matches(keyPattern, key) else {
            throw TamrWaiterError("the key must be a publishable key (tamr_pk_…)")
        }
        var token: String?
        var code: String?
        switch launch {
        case let .token(value)?: token = value
        case let .code(value)?: code = value
        case nil: break
        }
        return try waiterURL(
            host: host,
            address: address,
            query: [
                "key": key,
                "branch": branch,
                "lang": locale,
                "appearance": appearance.flatMap(encodeAppearance),
            ],
            fragment: [
                "token": token,
                "code": code,
                "embed": Platform.ios.rawValue,
                "sdk": TamrWaiterSDK.version,
                "table": table,
                "mode": mode?.rawValue,
                "debug": debug ? "1" : nil,
                "tableScan": tableScan,
            ]
        )
    }

    /// The address loaded again: without the spent token or code, on the last `ready`'s branch
    /// when it named none.
    static func relaunchURL(_ url: URL, lastReadyBranch: String?) -> URL {
        let text = url.absoluteString
        let beforeHash = text.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        let beforeQuery = beforeHash[0].split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        var query = decode(beforeQuery.count > 1 ? String(beforeQuery[1]) : "")
        var fragment = decode(beforeHash.count > 1 ? String(beforeHash[1]) : "")
        fragment.removeAll { $0.key == "token" || $0.key == "code" }
        if !query.contains(where: { $0.key == "branch" }), let lastReadyBranch {
            query.append((key: "branch", value: lastReadyBranch))
        }
        return build(
            String(beforeQuery[0]),
            encode(Dictionary(query.map { ($0.key, Optional($0.value)) }, uniquingKeysWith: { a, _ in a }),
                   order: TamrContract.queryKeys + query.map(\.key)),
            encode(Dictionary(fragment.map { ($0.key, Optional($0.value)) }, uniquingKeysWith: { a, _ in a }),
                   order: TamrContract.fragmentKeys + fragment.map(\.key))
        )
    }

    /// The `appearance` query value: the set fields as base64url JSON, keys sorted so one look is
    /// one address; nil when none is set.
    static func encodeAppearance(_ appearance: Appearance) -> String? {
        guard let data = try? JSONEncoder().encode(appearance),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        let set = object.filter { !($0.value is NSNull) }
        guard !set.isEmpty,
              let json = try? JSONSerialization.data(withJSONObject: set, options: [.sortedKeys, .withoutEscapingSlashes])
        else { return nil }
        return json.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Form encoding, as the page's `URLSearchParams` writes it: letters, digits and `-._*` as
    /// they are, a space as `+`, every other byte `%XX`.
    private static func component(_ value: String) -> String {
        var out = ""
        for byte in value.utf8 {
            switch byte {
            case UInt8(ascii: "a")...UInt8(ascii: "z"), UInt8(ascii: "A")...UInt8(ascii: "Z"),
                 UInt8(ascii: "0")...UInt8(ascii: "9"), UInt8(ascii: "-"), UInt8(ascii: "."),
                 UInt8(ascii: "_"), UInt8(ascii: "*"):
                out.append(Character(UnicodeScalar(byte)))
            case UInt8(ascii: " "):
                out.append("+")
            default:
                out += String(format: "%%%02X", byte)
            }
        }
        return out
    }

    private static func encode(_ values: [String: String?], order: [String]) -> String {
        var seen = Set<String>()
        return order.compactMap { key -> String? in
            guard seen.insert(key).inserted, let value = values[key] ?? nil, !value.isEmpty else { return nil }
            return "\(component(key))=\(component(value))"
        }.joined(separator: "&")
    }

    private static func decode(_ text: String) -> [(key: String, value: String)] {
        text.split(separator: "&").map { pair in
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let plain = { (s: Substring) in
                s.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? String(s)
            }
            return (key: plain(parts[0]), value: parts.count > 1 ? plain(parts[1]) : "")
        }
    }

    private static func build(_ base: String, _ query: String, _ fragment: String) -> URL {
        URL(string: base + (query.isEmpty ? "" : "?" + query) + (fragment.isEmpty ? "" : "#" + fragment))!
    }

    private static func matches(_ pattern: NSRegularExpression, _ value: String) -> Bool {
        pattern.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
    }
}
