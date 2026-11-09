// Generated from packages/sdk-contract by `pnpm sdk:generate`. Do not edit.

import Foundation

/// Constants of the bridge contract.
public enum TamrContract {
    /// The envelope's `v`.
    public static let bridgeVersion: Int = 1
    /// A sender gives up on an answer after this long.
    public static let replyTimeoutMs: Int = 15000
    /// How many message ids each side remembers to drop repeats.
    public static let dedupeWindow: Int = 500
    /// The name the page posts to: the handler, channel or listener each shell registers before
    /// the first load.
    public static let bridgeHandler: String = "TamrBridge"
    /// The global the shell calls to deliver a message: `window.<pageReceiver>.receive(json)`.
    public static let pageReceiver: String = "tamr"
    /// What a shell may announce in host.hello.
    public static let hostCapabilities: [String] = ["identity", "cart", "visibility", "microphone", "log", "orders", "pay"]
    /// What the page may announce in ready.
    public static let pageCapabilities: [String] = ["identity", "cart", "visibility", "context", "appearance", "text", "starters", "locale", "restrictions", "chat.send", "chat.new", "review", "state", "orders", "pay"]
    /// The waiter page's query params: each value is its own cached document.
    public static let queryKeys: [String] = ["key", "branch", "lang", "appearance"]
    /// The waiter page's fragment params: read in the browser, never sent to a server.
    public static let fragmentKeys: [String] = ["token", "code", "embed", "sdk", "table", "mode", "debug", "parent", "tableScan"]
}

/// A message that does not match the contract.
public struct ContractError: Error, CustomStringConvertible {
    public let description: String
}

/// A field sent to the page: set it, or reset it to the restaurant's own.
/// Leave it nil to keep what was sent before.
public enum Patch<Value: Codable & Sendable & Equatable>: Sendable, Equatable {
    case set(Value)
    case reset
}

/// One message off the bridge, with its envelope. `raw` is the JSON as received.
public struct Envelope<Message: Sendable>: Sendable {
    public let id: String
    public let ts: Int
    public let replyTo: String?
    public let message: Message
    public let raw: String
}

extension KeyedDecodingContainer {
    fileprivate func decodePatch<V>(_ type: V.Type, forKey key: Key) throws -> Patch<V>? {
        guard contains(key) else { return nil }
        return try decodeNil(forKey: key) ? .reset : .set(decode(V.self, forKey: key))
    }
}

extension KeyedEncodingContainer {
    fileprivate mutating func encodePatch<V>(_ patch: Patch<V>?, forKey key: Key) throws {
        switch patch {
        case nil: break
        case .reset?: try encodeNil(forKey: key)
        case let .set(value)?: try encode(value, forKey: key)
        }
    }
}

private struct Head: Decodable {
    let v: Int
    let id: String
    let type: String
    let ts: Int
    let replyTo: String?
}

private struct Box<T: Decodable>: Decodable {
    let data: T
}

private struct EmptyKeys: CodingKey {
    var stringValue: String { "" }
    var intValue: Int? { nil }
    init?(stringValue: String) { return nil }
    init?(intValue: Int) { return nil }
}

private struct AnyData: Encodable {
    let value: (any Encodable)?
    func encode(to encoder: Encoder) throws {
        if let value {
            try value.encode(to: encoder)
        } else {
            _ = encoder.container(keyedBy: EmptyKeys.self)
        }
    }
}

private struct Out: Encodable {
    let v: Int
    let id: String
    let type: String
    let ts: Int
    let data: AnyData
    let replyTo: String?
}

/// Allergen. New values may be added: keep a default branch.
public struct Allergen: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }

    public static let gluten = Allergen(rawValue: "gluten")
    public static let dairy = Allergen(rawValue: "dairy")
    public static let egg = Allergen(rawValue: "egg")
    public static let nuts = Allergen(rawValue: "nuts")
    public static let sesame = Allergen(rawValue: "sesame")
    public static let soy = Allergen(rawValue: "soy")
    public static let fish = Allergen(rawValue: "fish")
    public static let shellfish = Allergen(rawValue: "shellfish")
    public static let peanut = Allergen(rawValue: "peanut")
    public static let mustard = Allergen(rawValue: "mustard")

    /// Every value this version knows.
    public static let allKnown: [Allergen] = [.gluten, .dairy, .egg, .nuts, .sesame, .soy, .fish, .shellfish, .peanut, .mustard]

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard Self.allKnown.contains(Self(rawValue: raw)) else {
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown Allergen \(raw)")
                }
                self = Self(rawValue: raw)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// BookingStatus. A value this version does not know reads as `unknown`. New values may be
/// added: keep a default branch.
public struct BookingStatus: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }

    public static let requested = BookingStatus(rawValue: "requested")
    public static let confirmed = BookingStatus(rawValue: "confirmed")
    public static let cancelled = BookingStatus(rawValue: "cancelled")
    public static let unknown = BookingStatus(rawValue: "unknown")

    /// Every value this version knows.
    public static let allKnown: [BookingStatus] = [.requested, .confirmed, .cancelled, .unknown]

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = Self.allKnown.contains(Self(rawValue: raw)) ? Self(rawValue: raw) : .unknown
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// CartOrigin. A value this version does not know reads as `unknown`. New values may be
/// added: keep a default branch.
public struct CartOrigin: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }

    public static let waiter = CartOrigin(rawValue: "waiter")
    public static let diner = CartOrigin(rawValue: "diner")
    public static let unknown = CartOrigin(rawValue: "unknown")

    /// Every value this version knows.
    public static let allKnown: [CartOrigin] = [.waiter, .diner, .unknown]

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = Self.allKnown.contains(Self(rawValue: raw)) ? Self(rawValue: raw) : .unknown
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// ChatView. A value this version does not know reads as `unknown`. New values may be added:
/// keep a default branch.
public struct ChatView: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }

    public static let welcome = ChatView(rawValue: "welcome")
    public static let conversation = ChatView(rawValue: "conversation")
    public static let unknown = ChatView(rawValue: "unknown")

    /// Every value this version knows.
    public static let allKnown: [ChatView] = [.welcome, .conversation, .unknown]

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = Self.allKnown.contains(Self(rawValue: raw)) ? Self(rawValue: raw) : .unknown
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Corners. New values may be added: keep a default branch.
public struct Corners: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }

    public static let round = Corners(rawValue: "round")
    public static let soft = Corners(rawValue: "soft")
    public static let square = Corners(rawValue: "square")

    /// Every value this version knows.
    public static let allKnown: [Corners] = [.round, .soft, .square]

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard Self.allKnown.contains(Self(rawValue: raw)) else {
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown Corners \(raw)")
                }
                self = Self(rawValue: raw)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Diet. New values may be added: keep a default branch.
public struct Diet: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }

    public static let vegan = Diet(rawValue: "vegan")
    public static let vegetarian = Diet(rawValue: "vegetarian")
    public static let glutenFree = Diet(rawValue: "gluten_free")
    public static let halal = Diet(rawValue: "halal")
    public static let kosher = Diet(rawValue: "kosher")
    public static let dairyFree = Diet(rawValue: "dairy_free")
    public static let nutFree = Diet(rawValue: "nut_free")
    public static let keto = Diet(rawValue: "keto")

    /// Every value this version knows.
    public static let allKnown: [Diet] = [.vegan, .vegetarian, .glutenFree, .halal, .kosher, .dairyFree, .nutFree, .keto]

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard Self.allKnown.contains(Self(rawValue: raw)) else {
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown Diet \(raw)")
                }
                self = Self(rawValue: raw)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// EscalationReason. A value this version does not know reads as `unknown_other`. New values
/// may be added: keep a default branch.
public struct EscalationReason: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }

    public static let dinerRequestedStaff = EscalationReason(rawValue: "diner_requested_staff")
    public static let allergenSevere = EscalationReason(rawValue: "allergen_severe")
    public static let offMenuQuestion = EscalationReason(rawValue: "off_menu_question")
    public static let orderPlacement = EscalationReason(rawValue: "order_placement")
    public static let complaint = EscalationReason(rawValue: "complaint")
    public static let reservation = EscalationReason(rawValue: "reservation")
    public static let payment = EscalationReason(rawValue: "payment")
    public static let unknownOther = EscalationReason(rawValue: "unknown_other")

    /// Every value this version knows.
    public static let allKnown: [EscalationReason] = [.dinerRequestedStaff, .allergenSevere, .offMenuQuestion, .orderPlacement, .complaint, .reservation, .payment, .unknownOther]

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = Self.allKnown.contains(Self(rawValue: raw)) ? Self(rawValue: raw) : .unknownOther
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Fulfilment. A value this version does not know reads as `unknown`. New values may be
/// added: keep a default branch.
public struct Fulfilment: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }

    public static let dineIn = Fulfilment(rawValue: "dine_in")
    public static let pickup = Fulfilment(rawValue: "pickup")
    public static let unknown = Fulfilment(rawValue: "unknown")

    /// Every value this version knows.
    public static let allKnown: [Fulfilment] = [.dineIn, .pickup, .unknown]

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = Self.allKnown.contains(Self(rawValue: raw)) ? Self(rawValue: raw) : .unknown
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// IdentityRequestReason. A value this version does not know reads as `unknown`. New values
/// may be added: keep a default branch.
public struct IdentityRequestReason: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }

    public static let firstOpen = IdentityRequestReason(rawValue: "first_open")
    public static let expired = IdentityRequestReason(rawValue: "expired")
    public static let refused = IdentityRequestReason(rawValue: "refused")
    public static let unknown = IdentityRequestReason(rawValue: "unknown")

    /// Every value this version knows.
    public static let allKnown: [IdentityRequestReason] = [.firstOpen, .expired, .refused, .unknown]

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = Self.allKnown.contains(Self(rawValue: raw)) ? Self(rawValue: raw) : .unknown
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// LineRefusal. A value this version does not know reads as `other`. New values may be added:
/// keep a default branch.
public struct LineRefusal: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }

    public static let soldOut = LineRefusal(rawValue: "sold_out")
    public static let notFound = LineRefusal(rawValue: "not_found")
    public static let limit = LineRefusal(rawValue: "limit")
    public static let other = LineRefusal(rawValue: "other")

    /// Every value this version knows.
    public static let allKnown: [LineRefusal] = [.soldOut, .notFound, .limit, .other]

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = Self.allKnown.contains(Self(rawValue: raw)) ? Self(rawValue: raw) : .other
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// LogLevel. A value this version does not know reads as `unknown`. New values may be added:
/// keep a default branch.
public struct LogLevel: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }

    public static let info = LogLevel(rawValue: "info")
    public static let warn = LogLevel(rawValue: "warn")
    public static let error = LogLevel(rawValue: "error")
    public static let unknown = LogLevel(rawValue: "unknown")

    /// Every value this version knows.
    public static let allKnown: [LogLevel] = [.info, .warn, .error, .unknown]

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = Self.allKnown.contains(Self(rawValue: raw)) ? Self(rawValue: raw) : .unknown
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// OrderStatus. A value this version does not know reads as `unknown`. New values may be
/// added: keep a default branch.
public struct OrderStatus: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }

    public static let awaitingPayment = OrderStatus(rawValue: "awaiting_payment")
    public static let sent = OrderStatus(rawValue: "sent")
    public static let accepted = OrderStatus(rawValue: "accepted")
    public static let served = OrderStatus(rawValue: "served")
    public static let declined = OrderStatus(rawValue: "declined")
    public static let cancelled = OrderStatus(rawValue: "cancelled")
    public static let expired = OrderStatus(rawValue: "expired")
    public static let unknown = OrderStatus(rawValue: "unknown")

    /// Every value this version knows.
    public static let allKnown: [OrderStatus] = [.awaitingPayment, .sent, .accepted, .served, .declined, .cancelled, .expired, .unknown]

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = Self.allKnown.contains(Self(rawValue: raw)) ? Self(rawValue: raw) : .unknown
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Platform. New values may be added: keep a default branch.
public struct Platform: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }

    public static let flutter = Platform(rawValue: "flutter")
    public static let reactNative = Platform(rawValue: "react-native")
    public static let ios = Platform(rawValue: "ios")
    public static let android = Platform(rawValue: "android")
    public static let web = Platform(rawValue: "web")

    /// Every value this version knows.
    public static let allKnown: [Platform] = [.flutter, .reactNative, .ios, .android, .web]

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard Self.allKnown.contains(Self(rawValue: raw)) else {
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown Platform \(raw)")
                }
                self = Self(rawValue: raw)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// ReplyErrorCode. A value this version does not know reads as `failed`. New values may be
/// added: keep a default branch.
public struct ReplyErrorCode: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }

    public static let invalid = ReplyErrorCode(rawValue: "invalid")
    public static let unsupported = ReplyErrorCode(rawValue: "unsupported")
    public static let busy = ReplyErrorCode(rawValue: "busy")
    public static let notAllowed = ReplyErrorCode(rawValue: "not_allowed")
    public static let failed = ReplyErrorCode(rawValue: "failed")

    /// Every value this version knows.
    public static let allKnown: [ReplyErrorCode] = [.invalid, .unsupported, .busy, .notAllowed, .failed]

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = Self.allKnown.contains(Self(rawValue: raw)) ? Self(rawValue: raw) : .failed
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Scheme. New values may be added: keep a default branch.
public struct Scheme: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }

    public static let light = Scheme(rawValue: "light")
    public static let dark = Scheme(rawValue: "dark")
    public static let auto = Scheme(rawValue: "auto")

    /// Every value this version knows.
    public static let allKnown: [Scheme] = [.light, .dark, .auto]

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard Self.allKnown.contains(Self(rawValue: raw)) else {
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown Scheme \(raw)")
                }
                self = Self(rawValue: raw)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// ServiceMode. New values may be added: keep a default branch.
public struct ServiceMode: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }

    public static let dineIn = ServiceMode(rawValue: "dine_in")
    public static let pickup = ServiceMode(rawValue: "pickup")
    public static let delivery = ServiceMode(rawValue: "delivery")

    /// Every value this version knows.
    public static let allKnown: [ServiceMode] = [.dineIn, .pickup, .delivery]

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard Self.allKnown.contains(Self(rawValue: raw)) else {
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown ServiceMode \(raw)")
                }
                self = Self(rawValue: raw)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// ServiceRequest. A value this version does not know reads as `other`. New values may be
/// added: keep a default branch.
public struct ServiceRequest: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }

    public static let orderNow = ServiceRequest(rawValue: "order_now")
    public static let water = ServiceRequest(rawValue: "water")
    public static let check = ServiceRequest(rawValue: "check")
    public static let extraNapkins = ServiceRequest(rawValue: "extra_napkins")
    public static let refill = ServiceRequest(rawValue: "refill")
    public static let other = ServiceRequest(rawValue: "other")

    /// Every value this version knows.
    public static let allKnown: [ServiceRequest] = [.orderNow, .water, .check, .extraNapkins, .refill, .other]

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = Self.allKnown.contains(Self(rawValue: raw)) ? Self(rawValue: raw) : .other
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// ThemeScheme. New values may be added: keep a default branch.
public struct ThemeScheme: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }

    public static let light = ThemeScheme(rawValue: "light")
    public static let dark = ThemeScheme(rawValue: "dark")

    /// Every value this version knows.
    public static let allKnown: [ThemeScheme] = [.light, .dark]

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard Self.allKnown.contains(Self(rawValue: raw)) else {
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown ThemeScheme \(raw)")
                }
                self = Self(rawValue: raw)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Urgency. A value this version does not know reads as `unknown`. New values may be added:
/// keep a default branch.
public struct Urgency: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }

    public static let normal = Urgency(rawValue: "normal")
    public static let high = Urgency(rawValue: "high")
    public static let unknown = Urgency(rawValue: "unknown")

    /// Every value this version knows.
    public static let allKnown: [Urgency] = [.normal, .high, .unknown]

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = Self.allKnown.contains(Self(rawValue: raw)) ? Self(rawValue: raw) : .unknown
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// WaiterCallSource. A value this version does not know reads as `unknown`. New values may be
/// added: keep a default branch.
public struct WaiterCallSource: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }

    public static let request = WaiterCallSource(rawValue: "request")
    public static let escalation = WaiterCallSource(rawValue: "escalation")
    public static let unknown = WaiterCallSource(rawValue: "unknown")

    /// Every value this version knows.
    public static let allKnown: [WaiterCallSource] = [.request, .escalation, .unknown]

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = Self.allKnown.contains(Self(rawValue: raw)) ? Self(rawValue: raw) : .unknown
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Look and what is shown. Over the bridge, null resets a field to the restaurant's own and a
/// field left out keeps its value.
public struct Appearance: Codable, Sendable, Equatable {
    public var scheme: Patch<Scheme>?
    public var accent: Patch<String>?
    public var accentSecondary: Patch<String>?
    public var paper: Patch<String>?
    public var text: Patch<String>?
    public var displayFont: Patch<String>?
    public var uiFont: Patch<String>?
    public var corners: Patch<Corners>?
    public var showHeader: Patch<Bool>?
    public var showLogo: Patch<Bool>?
    public var showStarters: Patch<Bool>?
    public var showBack: Patch<Bool>?
    public var showPoweredBy: Patch<Bool>?
    public var hideVoice: Patch<Bool>?

    public init(scheme: Patch<Scheme>? = nil, accent: Patch<String>? = nil, accentSecondary: Patch<String>? = nil, paper: Patch<String>? = nil, text: Patch<String>? = nil, displayFont: Patch<String>? = nil, uiFont: Patch<String>? = nil, corners: Patch<Corners>? = nil, showHeader: Patch<Bool>? = nil, showLogo: Patch<Bool>? = nil, showStarters: Patch<Bool>? = nil, showBack: Patch<Bool>? = nil, showPoweredBy: Patch<Bool>? = nil, hideVoice: Patch<Bool>? = nil) {
        self.scheme = scheme
        self.accent = accent
        self.accentSecondary = accentSecondary
        self.paper = paper
        self.text = text
        self.displayFont = displayFont
        self.uiFont = uiFont
        self.corners = corners
        self.showHeader = showHeader
        self.showLogo = showLogo
        self.showStarters = showStarters
        self.showBack = showBack
        self.showPoweredBy = showPoweredBy
        self.hideVoice = hideVoice
    }

    private enum CodingKeys: String, CodingKey {
        case scheme, accent, accentSecondary, paper, text, displayFont, uiFont, corners, showHeader, showLogo, showStarters, showBack, showPoweredBy, hideVoice
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        scheme = try c.decodePatch(Scheme.self, forKey: .scheme)
        accent = try c.decodePatch(String.self, forKey: .accent)
        accentSecondary = try c.decodePatch(String.self, forKey: .accentSecondary)
        paper = try c.decodePatch(String.self, forKey: .paper)
        text = try c.decodePatch(String.self, forKey: .text)
        displayFont = try c.decodePatch(String.self, forKey: .displayFont)
        uiFont = try c.decodePatch(String.self, forKey: .uiFont)
        corners = try c.decodePatch(Corners.self, forKey: .corners)
        showHeader = try c.decodePatch(Bool.self, forKey: .showHeader)
        showLogo = try c.decodePatch(Bool.self, forKey: .showLogo)
        showStarters = try c.decodePatch(Bool.self, forKey: .showStarters)
        showBack = try c.decodePatch(Bool.self, forKey: .showBack)
        showPoweredBy = try c.decodePatch(Bool.self, forKey: .showPoweredBy)
        hideVoice = try c.decodePatch(Bool.self, forKey: .hideVoice)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodePatch(scheme, forKey: .scheme)
        try c.encodePatch(accent, forKey: .accent)
        try c.encodePatch(accentSecondary, forKey: .accentSecondary)
        try c.encodePatch(paper, forKey: .paper)
        try c.encodePatch(text, forKey: .text)
        try c.encodePatch(displayFont, forKey: .displayFont)
        try c.encodePatch(uiFont, forKey: .uiFont)
        try c.encodePatch(corners, forKey: .corners)
        try c.encodePatch(showHeader, forKey: .showHeader)
        try c.encodePatch(showLogo, forKey: .showLogo)
        try c.encodePatch(showStarters, forKey: .showStarters)
        try c.encodePatch(showBack, forKey: .showBack)
        try c.encodePatch(showPoweredBy, forKey: .showPoweredBy)
        try c.encodePatch(hideVoice, forKey: .hideVoice)
    }
}

public struct Booking: Codable, Sendable, Equatable {
    public var bookingId: String
    public var status: BookingStatus
    public var branch: String
    public var date: String
    public var time: String
    public var partySize: Int

    public init(bookingId: String, status: BookingStatus, branch: String, date: String, time: String, partySize: Int) {
        self.bookingId = bookingId
        self.status = status
        self.branch = branch
        self.date = date
        self.time = time
        self.partySize = partySize
    }

    private enum CodingKeys: String, CodingKey {
        case bookingId, status, branch, date, time, partySize
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bookingId = try c.decode(String.self, forKey: .bookingId)
        status = try c.decode(BookingStatus.self, forKey: .status)
        branch = try c.decode(String.self, forKey: .branch)
        date = try c.decode(String.self, forKey: .date)
        time = try c.decode(String.self, forKey: .time)
        partySize = try c.decode(Int.self, forKey: .partySize)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(bookingId, forKey: .bookingId)
        try c.encode(status, forKey: .status)
        try c.encode(branch, forKey: .branch)
        try c.encode(date, forKey: .date)
        try c.encode(time, forKey: .time)
        try c.encode(partySize, forKey: .partySize)
    }
}

/// Lines the waiter or the diner proposes to the host's cart; the app answers with a reply
/// holding one answer per line.
public struct CartChange: Codable, Sendable, Equatable {
    public var lines: [CartLine]
    public var origin: CartOrigin
    public var conversationId: String

    public init(lines: [CartLine], origin: CartOrigin, conversationId: String) {
        self.lines = lines
        self.origin = origin
        self.conversationId = conversationId
    }

    private enum CodingKeys: String, CodingKey {
        case lines, origin, conversationId
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lines = try c.decode([CartLine].self, forKey: .lines)
        origin = try c.decode(CartOrigin.self, forKey: .origin)
        conversationId = try c.decode(String.self, forKey: .conversationId)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(lines, forKey: .lines)
        try c.encode(origin, forKey: .origin)
        try c.encode(conversationId, forKey: .conversationId)
    }
}

/// A line the waiter proposes to the host's cart. Tamr's ids always, the host's ids when
/// mapped, and enough to rebuild the line with no mapping (ADR 0009). Money is minor units as
/// a string. A set built from other dishes carries its picks (#560).
public struct CartLine: Codable, Sendable, Equatable {
    /// Unique per proposed line: the host answers and dedupes by it.
    public var lineId: String
    /// Tamr's id for the dish.
    public var dishId: String
    /// Tamr's id for the size; null for a dish sold in one size.
    public var variantId: String?
    /// Tamr's ids for the chosen options.
    public var optionIds: [String]
    /// The host's id for the dish at this branch; null when not mapped.
    public var externalId: String?
    /// The host's id for the size; null when not mapped.
    public var variantExternalId: String?
    /// The host's ids for the options, one per entry of optionIds; null where not mapped.
    public var optionExternalIds: [String?]
    public var title: String
    /// The size as the menu labels it; null for a dish with one size.
    public var variantLabel: String?
    /// The chosen options' names, in the order of optionIds.
    public var choices: [String]
    public var unitPrice: String
    public var currency: String
    public var imageUrl: String?
    /// How many of the line. For a set, how many whole sets: picks included.
    public var quantity: Int
    /// The diner's own request for the kitchen ("no onions").
    public var note: String?
    /// A set's picks, in the order of its choices (#560). Absent on any other line. Each pick's
    /// count is per one set; quantity multiplies the whole set.
    public var picks: [CartPick]?

    public init(lineId: String, dishId: String, variantId: String?, optionIds: [String], externalId: String?, variantExternalId: String?, optionExternalIds: [String?], title: String, variantLabel: String?, choices: [String], unitPrice: String, currency: String, imageUrl: String?, quantity: Int, note: String?, picks: [CartPick]? = nil) {
        self.lineId = lineId
        self.dishId = dishId
        self.variantId = variantId
        self.optionIds = optionIds
        self.externalId = externalId
        self.variantExternalId = variantExternalId
        self.optionExternalIds = optionExternalIds
        self.title = title
        self.variantLabel = variantLabel
        self.choices = choices
        self.unitPrice = unitPrice
        self.currency = currency
        self.imageUrl = imageUrl
        self.quantity = quantity
        self.note = note
        self.picks = picks
    }

    private enum CodingKeys: String, CodingKey {
        case lineId, dishId, variantId, optionIds, externalId, variantExternalId, optionExternalIds, title, variantLabel, choices, unitPrice, currency, imageUrl, quantity, note, picks
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lineId = try c.decode(String.self, forKey: .lineId)
        dishId = try c.decode(String.self, forKey: .dishId)
        variantId = try c.decode(String?.self, forKey: .variantId)
        optionIds = try c.decode([String].self, forKey: .optionIds)
        externalId = try c.decode(String?.self, forKey: .externalId)
        variantExternalId = try c.decode(String?.self, forKey: .variantExternalId)
        optionExternalIds = try c.decode([String?].self, forKey: .optionExternalIds)
        title = try c.decode(String.self, forKey: .title)
        variantLabel = try c.decode(String?.self, forKey: .variantLabel)
        choices = try c.decode([String].self, forKey: .choices)
        unitPrice = try c.decode(String.self, forKey: .unitPrice)
        currency = try c.decode(String.self, forKey: .currency)
        imageUrl = try c.decode(String?.self, forKey: .imageUrl)
        quantity = try c.decode(Int.self, forKey: .quantity)
        note = try c.decode(String?.self, forKey: .note)
        picks = try c.decodeIfPresent([CartPick].self, forKey: .picks)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(lineId, forKey: .lineId)
        try c.encode(dishId, forKey: .dishId)
        try c.encode(variantId, forKey: .variantId)
        try c.encode(optionIds, forKey: .optionIds)
        try c.encode(externalId, forKey: .externalId)
        try c.encode(variantExternalId, forKey: .variantExternalId)
        try c.encode(optionExternalIds, forKey: .optionExternalIds)
        try c.encode(title, forKey: .title)
        try c.encode(variantLabel, forKey: .variantLabel)
        try c.encode(choices, forKey: .choices)
        try c.encode(unitPrice, forKey: .unitPrice)
        try c.encode(currency, forKey: .currency)
        try c.encode(imageUrl, forKey: .imageUrl)
        try c.encode(quantity, forKey: .quantity)
        try c.encode(note, forKey: .note)
        try c.encodeIfPresent(picks, forKey: .picks)
    }
}

/// One option picked in a set: Tamr's ids always, the host's when mapped, and its words.
/// count is per one set; the line's quantity multiplies the whole set.
public struct CartPick: Codable, Sendable, Equatable {
    /// Tamr's id for the option picked, one of the set's choices.
    public var pickId: String
    /// Tamr's id for the dish the option is.
    public var dishId: String
    /// Tamr's id for the dish's size when the set names one; null otherwise.
    public var variantId: String?
    /// The host's id for that dish at this branch; null when not mapped.
    public var externalId: String?
    /// The host's id for that size; null when not mapped.
    public var variantExternalId: String?
    public var title: String
    /// The size as the set names it; null for none.
    public var variantLabel: String?
    /// Pieces in one pick, as the set defines it: "2 x salmon nigiri" is 2.
    public var pieces: Int
    /// Times this option is picked in ONE set. The line's quantity multiplies the whole set,
    /// picks included: 2 sets with count 3 hold 6 of it.
    public var count: Int

    public init(pickId: String, dishId: String, variantId: String?, externalId: String?, variantExternalId: String?, title: String, variantLabel: String?, pieces: Int, count: Int) {
        self.pickId = pickId
        self.dishId = dishId
        self.variantId = variantId
        self.externalId = externalId
        self.variantExternalId = variantExternalId
        self.title = title
        self.variantLabel = variantLabel
        self.pieces = pieces
        self.count = count
    }

    private enum CodingKeys: String, CodingKey {
        case pickId, dishId, variantId, externalId, variantExternalId, title, variantLabel, pieces, count
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pickId = try c.decode(String.self, forKey: .pickId)
        dishId = try c.decode(String.self, forKey: .dishId)
        variantId = try c.decode(String?.self, forKey: .variantId)
        externalId = try c.decode(String?.self, forKey: .externalId)
        variantExternalId = try c.decode(String?.self, forKey: .variantExternalId)
        title = try c.decode(String.self, forKey: .title)
        variantLabel = try c.decode(String?.self, forKey: .variantLabel)
        pieces = try c.decode(Int.self, forKey: .pieces)
        count = try c.decode(Int.self, forKey: .count)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(pickId, forKey: .pickId)
        try c.encode(dishId, forKey: .dishId)
        try c.encode(variantId, forKey: .variantId)
        try c.encode(externalId, forKey: .externalId)
        try c.encode(variantExternalId, forKey: .variantExternalId)
        try c.encode(title, forKey: .title)
        try c.encode(variantLabel, forKey: .variantLabel)
        try c.encode(pieces, forKey: .pieces)
        try c.encode(count, forKey: .count)
    }
}

public struct CartSnapshotData: Codable, Sendable, Equatable {
    public var lines: [SnapshotLine]

    public init(lines: [SnapshotLine]) {
        self.lines = lines
    }

    private enum CodingKeys: String, CodingKey {
        case lines
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lines = try c.decode([SnapshotLine].self, forKey: .lines)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(lines, forKey: .lines)
    }
}

public struct ChatSendData: Codable, Sendable, Equatable {
    public var text: String

    public init(text: String) {
        self.text = text
    }

    private enum CodingKeys: String, CodingKey {
        case text
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = try c.decode(String.self, forKey: .text)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(text, forKey: .text)
    }
}

public struct CheckoutData: Codable, Sendable, Equatable {
    public var conversationId: String

    public init(conversationId: String) {
        self.conversationId = conversationId
    }

    private enum CodingKeys: String, CodingKey {
        case conversationId
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        conversationId = try c.decode(String.self, forKey: .conversationId)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(conversationId, forKey: .conversationId)
    }
}

public struct ContextData: Codable, Sendable, Equatable {
    public var branch: String?
    public var mode: ServiceMode?
    public var table: String?
    public var currency: String?
    public var tableScan: String?

    public init(branch: String? = nil, mode: ServiceMode? = nil, table: String? = nil, currency: String? = nil, tableScan: String? = nil) {
        self.branch = branch
        self.mode = mode
        self.table = table
        self.currency = currency
        self.tableScan = tableScan
    }

    private enum CodingKeys: String, CodingKey {
        case branch, mode, table, currency, tableScan
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        branch = try c.decodeIfPresent(String.self, forKey: .branch)
        mode = try c.decodeIfPresent(ServiceMode.self, forKey: .mode)
        table = try c.decodeIfPresent(String.self, forKey: .table)
        currency = try c.decodeIfPresent(String.self, forKey: .currency)
        tableScan = try c.decodeIfPresent(String.self, forKey: .tableScan)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(branch, forKey: .branch)
        try c.encodeIfPresent(mode, forKey: .mode)
        try c.encodeIfPresent(table, forKey: .table)
        try c.encodeIfPresent(currency, forKey: .currency)
        try c.encodeIfPresent(tableScan, forKey: .tableScan)
    }
}

public struct HostHelloData: Codable, Sendable, Equatable {
    public var sdk: String
    public var platform: Platform
    public var osVersion: String?
    public var capabilities: [String]

    public init(sdk: String, platform: Platform, osVersion: String? = nil, capabilities: [String]) {
        self.sdk = sdk
        self.platform = platform
        self.osVersion = osVersion
        self.capabilities = capabilities
    }

    private enum CodingKeys: String, CodingKey {
        case sdk, platform, osVersion, capabilities
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sdk = try c.decode(String.self, forKey: .sdk)
        platform = try c.decode(Platform.self, forKey: .platform)
        osVersion = try c.decodeIfPresent(String.self, forKey: .osVersion)
        capabilities = try c.decode([String].self, forKey: .capabilities)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(sdk, forKey: .sdk)
        try c.encode(platform, forKey: .platform)
        try c.encodeIfPresent(osVersion, forKey: .osVersion)
        try c.encode(capabilities, forKey: .capabilities)
    }
}

public struct IdentityRequestData: Codable, Sendable, Equatable {
    public var reason: IdentityRequestReason

    public init(reason: IdentityRequestReason) {
        self.reason = reason
    }

    private enum CodingKeys: String, CodingKey {
        case reason
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reason = try c.decode(IdentityRequestReason.self, forKey: .reason)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(reason, forKey: .reason)
    }
}

public struct IdentityTokenData: Codable, Sendable, Equatable {
    public var token: String?
    public var code: String?

    public init(token: String? = nil, code: String? = nil) {
        self.token = token
        self.code = code
    }

    private enum CodingKeys: String, CodingKey {
        case token, code
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        token = try c.decodeIfPresent(String.self, forKey: .token)
        code = try c.decodeIfPresent(String.self, forKey: .code)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(token, forKey: .token)
        try c.encodeIfPresent(code, forKey: .code)
    }
}

/// The host's answer for one proposed line.
public struct LineAnswer: Codable, Sendable, Equatable {
    public var lineId: String
    public var ok: Bool
    public var reason: LineRefusal?
    public var message: String?

    public init(lineId: String, ok: Bool, reason: LineRefusal? = nil, message: String? = nil) {
        self.lineId = lineId
        self.ok = ok
        self.reason = reason
        self.message = message
    }

    private enum CodingKeys: String, CodingKey {
        case lineId, ok, reason, message
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lineId = try c.decode(String.self, forKey: .lineId)
        ok = try c.decode(Bool.self, forKey: .ok)
        reason = try c.decodeIfPresent(LineRefusal.self, forKey: .reason)
        message = try c.decodeIfPresent(String.self, forKey: .message)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(lineId, forKey: .lineId)
        try c.encode(ok, forKey: .ok)
        try c.encodeIfPresent(reason, forKey: .reason)
        try c.encodeIfPresent(message, forKey: .message)
    }
}

public struct LocaleData: Codable, Sendable, Equatable {
    public var locale: String

    public init(locale: String) {
        self.locale = locale
    }

    private enum CodingKeys: String, CodingKey {
        case locale
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        locale = try c.decode(String.self, forKey: .locale)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(locale, forKey: .locale)
    }
}

public struct LogData: Codable, Sendable, Equatable {
    public var level: LogLevel
    public var message: String

    public init(level: LogLevel, message: String) {
        self.level = level
        self.message = message
    }

    private enum CodingKeys: String, CodingKey {
        case level, message
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        level = try c.decode(LogLevel.self, forKey: .level)
        message = try c.decode(String.self, forKey: .message)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(level, forKey: .level)
        try c.encode(message, forKey: .message)
    }
}

public struct OpenDish: Codable, Sendable, Equatable {
    public var dishId: String
    public var externalId: String?
    public var variantId: String?

    public init(dishId: String, externalId: String?, variantId: String?) {
        self.dishId = dishId
        self.externalId = externalId
        self.variantId = variantId
    }

    private enum CodingKeys: String, CodingKey {
        case dishId, externalId, variantId
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dishId = try c.decode(String.self, forKey: .dishId)
        externalId = try c.decode(String?.self, forKey: .externalId)
        variantId = try c.decode(String?.self, forKey: .variantId)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(dishId, forKey: .dishId)
        try c.encode(externalId, forKey: .externalId)
        try c.encode(variantId, forKey: .variantId)
    }
}

/// How one open of the chat went, for the Install page.
public struct OpenTiming: Codable, Sendable, Equatable {
    public var navigationStart: Int
    public var firstPaint: Int
    public var bridgeReady: Int
    public var interactive: Int
    public var `open`: Int?
    public var preloaded: Bool

    public init(navigationStart: Int, firstPaint: Int, bridgeReady: Int, interactive: Int, `open`: Int? = nil, preloaded: Bool) {
        self.navigationStart = navigationStart
        self.firstPaint = firstPaint
        self.bridgeReady = bridgeReady
        self.interactive = interactive
        self.open = `open`
        self.preloaded = preloaded
    }

    private enum CodingKeys: String, CodingKey {
        case navigationStart, firstPaint, bridgeReady, interactive, `open`, preloaded
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        navigationStart = try c.decode(Int.self, forKey: .navigationStart)
        firstPaint = try c.decode(Int.self, forKey: .firstPaint)
        bridgeReady = try c.decode(Int.self, forKey: .bridgeReady)
        interactive = try c.decode(Int.self, forKey: .interactive)
        open = try c.decodeIfPresent(Int.self, forKey: .`open`)
        preloaded = try c.decode(Bool.self, forKey: .preloaded)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(navigationStart, forKey: .navigationStart)
        try c.encode(firstPaint, forKey: .firstPaint)
        try c.encode(bridgeReady, forKey: .bridgeReady)
        try c.encode(interactive, forKey: .interactive)
        try c.encodeIfPresent(open, forKey: .`open`)
        try c.encode(preloaded, forKey: .preloaded)
    }
}

public struct OrderLine: Codable, Sendable, Equatable {
    public var dishId: String?
    public var externalId: String?
    public var title: String
    public var variantLabel: String?
    public var quantity: Int
    public var unitPrice: String

    public init(dishId: String?, externalId: String?, title: String, variantLabel: String?, quantity: Int, unitPrice: String) {
        self.dishId = dishId
        self.externalId = externalId
        self.title = title
        self.variantLabel = variantLabel
        self.quantity = quantity
        self.unitPrice = unitPrice
    }

    private enum CodingKeys: String, CodingKey {
        case dishId, externalId, title, variantLabel, quantity, unitPrice
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dishId = try c.decode(String?.self, forKey: .dishId)
        externalId = try c.decode(String?.self, forKey: .externalId)
        title = try c.decode(String.self, forKey: .title)
        variantLabel = try c.decode(String?.self, forKey: .variantLabel)
        quantity = try c.decode(Int.self, forKey: .quantity)
        unitPrice = try c.decode(String.self, forKey: .unitPrice)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(dishId, forKey: .dishId)
        try c.encode(externalId, forKey: .externalId)
        try c.encode(title, forKey: .title)
        try c.encode(variantLabel, forKey: .variantLabel)
        try c.encode(quantity, forKey: .quantity)
        try c.encode(unitPrice, forKey: .unitPrice)
    }
}

public struct OrderPlaced: Codable, Sendable, Equatable {
    public var orderId: String
    /// The short number staff call out, per branch and service day.
    public var number: Int
    public var status: OrderStatus
    public var branch: String
    public var table: String?
    public var currency: String
    public var subtotal: String
    public var lines: [OrderLine]
    public var fulfilment: Fulfilment?
    public var pickupAt: Patch<String>?
    public var pickupCode: Patch<String>?

    public init(orderId: String, number: Int, status: OrderStatus, branch: String, table: String?, currency: String, subtotal: String, lines: [OrderLine], fulfilment: Fulfilment? = nil, pickupAt: Patch<String>? = nil, pickupCode: Patch<String>? = nil) {
        self.orderId = orderId
        self.number = number
        self.status = status
        self.branch = branch
        self.table = table
        self.currency = currency
        self.subtotal = subtotal
        self.lines = lines
        self.fulfilment = fulfilment
        self.pickupAt = pickupAt
        self.pickupCode = pickupCode
    }

    private enum CodingKeys: String, CodingKey {
        case orderId, number, status, branch, table, currency, subtotal, lines, fulfilment, pickupAt, pickupCode
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        orderId = try c.decode(String.self, forKey: .orderId)
        number = try c.decode(Int.self, forKey: .number)
        status = try c.decode(OrderStatus.self, forKey: .status)
        branch = try c.decode(String.self, forKey: .branch)
        table = try c.decode(String?.self, forKey: .table)
        currency = try c.decode(String.self, forKey: .currency)
        subtotal = try c.decode(String.self, forKey: .subtotal)
        lines = try c.decode([OrderLine].self, forKey: .lines)
        fulfilment = try c.decodeIfPresent(Fulfilment.self, forKey: .fulfilment)
        pickupAt = try c.decodePatch(String.self, forKey: .pickupAt)
        pickupCode = try c.decodePatch(String.self, forKey: .pickupCode)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(orderId, forKey: .orderId)
        try c.encode(number, forKey: .number)
        try c.encode(status, forKey: .status)
        try c.encode(branch, forKey: .branch)
        try c.encode(table, forKey: .table)
        try c.encode(currency, forKey: .currency)
        try c.encode(subtotal, forKey: .subtotal)
        try c.encode(lines, forKey: .lines)
        try c.encodeIfPresent(fulfilment, forKey: .fulfilment)
        try c.encodePatch(pickupAt, forKey: .pickupAt)
        try c.encodePatch(pickupCode, forKey: .pickupCode)
    }
}

public struct PaymentCompleted: Codable, Sendable, Equatable {
    public var paymentId: String
    public var amount: String
    public var currency: String
    public var orderId: String?

    public init(paymentId: String, amount: String, currency: String, orderId: String?) {
        self.paymentId = paymentId
        self.amount = amount
        self.currency = currency
        self.orderId = orderId
    }

    private enum CodingKeys: String, CodingKey {
        case paymentId, amount, currency, orderId
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        paymentId = try c.decode(String.self, forKey: .paymentId)
        amount = try c.decode(String.self, forKey: .amount)
        currency = try c.decode(String.self, forKey: .currency)
        orderId = try c.decode(String?.self, forKey: .orderId)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(paymentId, forKey: .paymentId)
        try c.encode(amount, forKey: .amount)
        try c.encode(currency, forKey: .currency)
        try c.encode(orderId, forKey: .orderId)
    }
}

public struct PaymentOpen: Codable, Sendable, Equatable {
    public var paymentId: String
    public var url: String

    public init(paymentId: String, url: String) {
        self.paymentId = paymentId
        self.url = url
    }

    private enum CodingKeys: String, CodingKey {
        case paymentId, url
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        paymentId = try c.decode(String.self, forKey: .paymentId)
        url = try c.decode(String.self, forKey: .url)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(paymentId, forKey: .paymentId)
        try c.encode(url, forKey: .url)
    }
}

public struct ReadyData: Codable, Sendable, Equatable {
    public var org: String
    public var branch: String?
    public var conversationId: String?
    public var capabilities: [String]

    public init(org: String, branch: String?, conversationId: String?, capabilities: [String]) {
        self.org = org
        self.branch = branch
        self.conversationId = conversationId
        self.capabilities = capabilities
    }

    private enum CodingKeys: String, CodingKey {
        case org, branch, conversationId, capabilities
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        org = try c.decode(String.self, forKey: .org)
        branch = try c.decode(String?.self, forKey: .branch)
        conversationId = try c.decode(String?.self, forKey: .conversationId)
        capabilities = try c.decode([String].self, forKey: .capabilities)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(org, forKey: .org)
        try c.encode(branch, forKey: .branch)
        try c.encode(conversationId, forKey: .conversationId)
        try c.encode(capabilities, forKey: .capabilities)
    }
}

/// The answer to the message named by replyTo: ok, or an error code; lines answers a cart
/// proposal line by line.
public struct Reply: Codable, Sendable, Equatable {
    public var ok: Bool
    public var lines: [LineAnswer]?
    public var unmapped: [UnmappedLine]?
    public var error: ReplyError?

    public init(ok: Bool, lines: [LineAnswer]? = nil, unmapped: [UnmappedLine]? = nil, error: ReplyError? = nil) {
        self.ok = ok
        self.lines = lines
        self.unmapped = unmapped
        self.error = error
    }

    private enum CodingKeys: String, CodingKey {
        case ok, lines, unmapped, error
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decode(Bool.self, forKey: .ok)
        lines = try c.decodeIfPresent([LineAnswer].self, forKey: .lines)
        unmapped = try c.decodeIfPresent([UnmappedLine].self, forKey: .unmapped)
        error = try c.decodeIfPresent(ReplyError.self, forKey: .error)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(ok, forKey: .ok)
        try c.encodeIfPresent(lines, forKey: .lines)
        try c.encodeIfPresent(unmapped, forKey: .unmapped)
        try c.encodeIfPresent(error, forKey: .error)
    }
}

public struct ReplyError: Codable, Sendable, Equatable {
    public var code: ReplyErrorCode
    public var message: String?

    public init(code: ReplyErrorCode, message: String? = nil) {
        self.code = code
        self.message = message
    }

    private enum CodingKeys: String, CodingKey {
        case code, message
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = try c.decode(ReplyErrorCode.self, forKey: .code)
        message = try c.decodeIfPresent(String.self, forKey: .message)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(code, forKey: .code)
        try c.encodeIfPresent(message, forKey: .message)
    }
}

public struct RestrictionsData: Codable, Sendable, Equatable {
    public var avoidAllergens: [Allergen]
    public var keepDiets: [Diet]

    public init(avoidAllergens: [Allergen], keepDiets: [Diet]) {
        self.avoidAllergens = avoidAllergens
        self.keepDiets = keepDiets
    }

    private enum CodingKeys: String, CodingKey {
        case avoidAllergens, keepDiets
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        avoidAllergens = try c.decode([Allergen].self, forKey: .avoidAllergens)
        keepDiets = try c.decode([Diet].self, forKey: .keepDiets)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(avoidAllergens, forKey: .avoidAllergens)
        try c.encode(keepDiets, forKey: .keepDiets)
    }
}

public struct ReviewDish: Codable, Sendable, Equatable {
    public var dishId: String?
    public var externalId: String?
    public var title: String

    public init(dishId: String? = nil, externalId: String? = nil, title: String) {
        self.dishId = dishId
        self.externalId = externalId
        self.title = title
    }

    private enum CodingKeys: String, CodingKey {
        case dishId, externalId, title
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dishId = try c.decodeIfPresent(String.self, forKey: .dishId)
        externalId = try c.decodeIfPresent(String.self, forKey: .externalId)
        title = try c.decode(String.self, forKey: .title)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(dishId, forKey: .dishId)
        try c.encodeIfPresent(externalId, forKey: .externalId)
        try c.encode(title, forKey: .title)
    }
}

public struct ReviewRequestData: Codable, Sendable, Equatable {
    public var orderId: String
    public var dishes: [ReviewDish]

    public init(orderId: String, dishes: [ReviewDish]) {
        self.orderId = orderId
        self.dishes = dishes
    }

    private enum CodingKeys: String, CodingKey {
        case orderId, dishes
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        orderId = try c.decode(String.self, forKey: .orderId)
        dishes = try c.decode([ReviewDish].self, forKey: .dishes)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(orderId, forKey: .orderId)
        try c.encode(dishes, forKey: .dishes)
    }
}

/// A line of the host's own cart, named by exactly one id: dishId or externalId.
public struct SnapshotLine: Codable, Sendable, Equatable {
    public var dishId: String?
    public var externalId: String?
    public var variantId: String?
    public var variantExternalId: String?
    public var optionIds: [String]?
    public var optionExternalIds: [String]?
    public var quantity: Int
    public var picks: [SnapshotPick]?

    public init(dishId: String? = nil, externalId: String? = nil, variantId: String? = nil, variantExternalId: String? = nil, optionIds: [String]? = nil, optionExternalIds: [String]? = nil, quantity: Int, picks: [SnapshotPick]? = nil) {
        self.dishId = dishId
        self.externalId = externalId
        self.variantId = variantId
        self.variantExternalId = variantExternalId
        self.optionIds = optionIds
        self.optionExternalIds = optionExternalIds
        self.quantity = quantity
        self.picks = picks
    }

    private enum CodingKeys: String, CodingKey {
        case dishId, externalId, variantId, variantExternalId, optionIds, optionExternalIds, quantity, picks
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dishId = try c.decodeIfPresent(String.self, forKey: .dishId)
        externalId = try c.decodeIfPresent(String.self, forKey: .externalId)
        variantId = try c.decodeIfPresent(String.self, forKey: .variantId)
        variantExternalId = try c.decodeIfPresent(String.self, forKey: .variantExternalId)
        optionIds = try c.decodeIfPresent([String].self, forKey: .optionIds)
        optionExternalIds = try c.decodeIfPresent([String].self, forKey: .optionExternalIds)
        quantity = try c.decode(Int.self, forKey: .quantity)
        picks = try c.decodeIfPresent([SnapshotPick].self, forKey: .picks)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(dishId, forKey: .dishId)
        try c.encodeIfPresent(externalId, forKey: .externalId)
        try c.encodeIfPresent(variantId, forKey: .variantId)
        try c.encodeIfPresent(variantExternalId, forKey: .variantExternalId)
        try c.encodeIfPresent(optionIds, forKey: .optionIds)
        try c.encodeIfPresent(optionExternalIds, forKey: .optionExternalIds)
        try c.encode(quantity, forKey: .quantity)
        try c.encodeIfPresent(picks, forKey: .picks)
    }
}

/// One pick of a set in the host's cart, named by pickId or by the host's externalId (with
/// variantExternalId when it keys on the size). count is per one set.
public struct SnapshotPick: Codable, Sendable, Equatable {
    public var pickId: String?
    public var externalId: String?
    public var variantExternalId: String?
    public var count: Int

    public init(pickId: String? = nil, externalId: String? = nil, variantExternalId: String? = nil, count: Int) {
        self.pickId = pickId
        self.externalId = externalId
        self.variantExternalId = variantExternalId
        self.count = count
    }

    private enum CodingKeys: String, CodingKey {
        case pickId, externalId, variantExternalId, count
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pickId = try c.decodeIfPresent(String.self, forKey: .pickId)
        externalId = try c.decodeIfPresent(String.self, forKey: .externalId)
        variantExternalId = try c.decodeIfPresent(String.self, forKey: .variantExternalId)
        count = try c.decode(Int.self, forKey: .count)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(pickId, forKey: .pickId)
        try c.encodeIfPresent(externalId, forKey: .externalId)
        try c.encodeIfPresent(variantExternalId, forKey: .variantExternalId)
        try c.encode(count, forKey: .count)
    }
}

public struct Starter: Codable, Sendable, Equatable {
    public var label: String
    /// Sent as the diner's message; the label when absent.
    public var prompt: String?

    public init(label: String, prompt: String? = nil) {
        self.label = label
        self.prompt = prompt
    }

    private enum CodingKeys: String, CodingKey {
        case label, prompt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label = try c.decode(String.self, forKey: .label)
        prompt = try c.decodeIfPresent(String.self, forKey: .prompt)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(label, forKey: .label)
        try c.encodeIfPresent(prompt, forKey: .prompt)
    }
}

public struct StartersData: Codable, Sendable, Equatable {
    public var items: [Starter]

    public init(items: [Starter]) {
        self.items = items
    }

    private enum CodingKeys: String, CodingKey {
        case items
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = try c.decode([Starter].self, forKey: .items)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(items, forKey: .items)
    }
}

public struct StateData: Codable, Sendable, Equatable {
    public var view: ChatView
    public var busy: Bool
    public var itemCount: Int
    public var conversationId: String?

    public init(view: ChatView, busy: Bool, itemCount: Int, conversationId: String?) {
        self.view = view
        self.busy = busy
        self.itemCount = itemCount
        self.conversationId = conversationId
    }

    private enum CodingKeys: String, CodingKey {
        case view, busy, itemCount, conversationId
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        view = try c.decode(ChatView.self, forKey: .view)
        busy = try c.decode(Bool.self, forKey: .busy)
        itemCount = try c.decode(Int.self, forKey: .itemCount)
        conversationId = try c.decode(String?.self, forKey: .conversationId)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(view, forKey: .view)
        try c.encode(busy, forKey: .busy)
        try c.encode(itemCount, forKey: .itemCount)
        try c.encode(conversationId, forKey: .conversationId)
    }
}

/// Wording, over the bridge only; merged like Appearance.
public struct Text: Codable, Sendable, Equatable {
    public var waiterName: Patch<String>?
    public var welcomeTitle: Patch<String>?
    public var welcomeSubtitle: Patch<String>?
    public var placeholder: Patch<String>?
    public var labels: TextLabels?

    public init(waiterName: Patch<String>? = nil, welcomeTitle: Patch<String>? = nil, welcomeSubtitle: Patch<String>? = nil, placeholder: Patch<String>? = nil, labels: TextLabels? = nil) {
        self.waiterName = waiterName
        self.welcomeTitle = welcomeTitle
        self.welcomeSubtitle = welcomeSubtitle
        self.placeholder = placeholder
        self.labels = labels
    }

    private enum CodingKeys: String, CodingKey {
        case waiterName, welcomeTitle, welcomeSubtitle, placeholder, labels
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        waiterName = try c.decodePatch(String.self, forKey: .waiterName)
        welcomeTitle = try c.decodePatch(String.self, forKey: .welcomeTitle)
        welcomeSubtitle = try c.decodePatch(String.self, forKey: .welcomeSubtitle)
        placeholder = try c.decodePatch(String.self, forKey: .placeholder)
        labels = try c.decodeIfPresent(TextLabels.self, forKey: .labels)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodePatch(waiterName, forKey: .waiterName)
        try c.encodePatch(welcomeTitle, forKey: .welcomeTitle)
        try c.encodePatch(welcomeSubtitle, forKey: .welcomeSubtitle)
        try c.encodePatch(placeholder, forKey: .placeholder)
        try c.encodeIfPresent(labels, forKey: .labels)
    }
}

public struct TextLabels: Codable, Sendable, Equatable {
    public var newChat: Patch<String>?
    public var tryAgain: Patch<String>?
    public var addToCart: Patch<String>?
    public var checkout: Patch<String>?
    public var callWaiter: Patch<String>?
    public var thinking: Patch<String>?

    public init(newChat: Patch<String>? = nil, tryAgain: Patch<String>? = nil, addToCart: Patch<String>? = nil, checkout: Patch<String>? = nil, callWaiter: Patch<String>? = nil, thinking: Patch<String>? = nil) {
        self.newChat = newChat
        self.tryAgain = tryAgain
        self.addToCart = addToCart
        self.checkout = checkout
        self.callWaiter = callWaiter
        self.thinking = thinking
    }

    private enum CodingKeys: String, CodingKey {
        case newChat, tryAgain, addToCart, checkout, callWaiter, thinking
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        newChat = try c.decodePatch(String.self, forKey: .newChat)
        tryAgain = try c.decodePatch(String.self, forKey: .tryAgain)
        addToCart = try c.decodePatch(String.self, forKey: .addToCart)
        checkout = try c.decodePatch(String.self, forKey: .checkout)
        callWaiter = try c.decodePatch(String.self, forKey: .callWaiter)
        thinking = try c.decodePatch(String.self, forKey: .thinking)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodePatch(newChat, forKey: .newChat)
        try c.encodePatch(tryAgain, forKey: .tryAgain)
        try c.encodePatch(addToCart, forKey: .addToCart)
        try c.encodePatch(checkout, forKey: .checkout)
        try c.encodePatch(callWaiter, forKey: .callWaiter)
        try c.encodePatch(thinking, forKey: .thinking)
    }
}

public struct ThemeData: Codable, Sendable, Equatable {
    public var scheme: ThemeScheme

    public init(scheme: ThemeScheme) {
        self.scheme = scheme
    }

    private enum CodingKeys: String, CodingKey {
        case scheme
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        scheme = try c.decode(ThemeScheme.self, forKey: .scheme)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(scheme, forKey: .scheme)
    }
}

public struct UnmappedLine: Codable, Sendable, Equatable {
    public var externalId: String

    public init(externalId: String) {
        self.externalId = externalId
    }

    private enum CodingKeys: String, CodingKey {
        case externalId
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        externalId = try c.decode(String.self, forKey: .externalId)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(externalId, forKey: .externalId)
    }
}

public struct VisibilityData: Codable, Sendable, Equatable {
    public var shown: Bool
    public var at: Int?

    public init(shown: Bool, at: Int? = nil) {
        self.shown = shown
        self.at = at
    }

    private enum CodingKeys: String, CodingKey {
        case shown, at
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        shown = try c.decode(Bool.self, forKey: .shown)
        at = try c.decodeIfPresent(Int.self, forKey: .at)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(shown, forKey: .shown)
        try c.encodeIfPresent(at, forKey: .at)
    }
}

public struct WaiterCalled: Codable, Sendable, Equatable {
    public var source: WaiterCallSource
    public var kind: ServiceRequest?
    public var reason: EscalationReason?
    public var urgency: Urgency?
    public var table: String?

    public init(source: WaiterCallSource, kind: ServiceRequest? = nil, reason: EscalationReason? = nil, urgency: Urgency? = nil, table: String?) {
        self.source = source
        self.kind = kind
        self.reason = reason
        self.urgency = urgency
        self.table = table
    }

    private enum CodingKeys: String, CodingKey {
        case source, kind, reason, urgency, table
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        source = try c.decode(WaiterCallSource.self, forKey: .source)
        kind = try c.decodeIfPresent(ServiceRequest.self, forKey: .kind)
        reason = try c.decodeIfPresent(EscalationReason.self, forKey: .reason)
        urgency = try c.decodeIfPresent(Urgency.self, forKey: .urgency)
        table = try c.decode(String?.self, forKey: .table)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(source, forKey: .source)
        try c.encodeIfPresent(kind, forKey: .kind)
        try c.encodeIfPresent(reason, forKey: .reason)
        try c.encodeIfPresent(urgency, forKey: .urgency)
        try c.encode(table, forKey: .table)
    }
}

public struct WaiterFragment: Codable, Sendable, Equatable {
    public var token: String?
    public var code: String?
    public var embed: Platform?
    public var sdk: String?
    public var table: String?
    public var tableScan: String?
    public var mode: ServiceMode?
    public var debug: String?
    public var parent: String?

    public init(token: String? = nil, code: String? = nil, embed: Platform? = nil, sdk: String? = nil, table: String? = nil, tableScan: String? = nil, mode: ServiceMode? = nil, debug: String? = nil, parent: String? = nil) {
        self.token = token
        self.code = code
        self.embed = embed
        self.sdk = sdk
        self.table = table
        self.tableScan = tableScan
        self.mode = mode
        self.debug = debug
        self.parent = parent
    }

    private enum CodingKeys: String, CodingKey {
        case token, code, embed, sdk, table, tableScan, mode, debug, parent
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        token = try c.decodeIfPresent(String.self, forKey: .token)
        code = try c.decodeIfPresent(String.self, forKey: .code)
        embed = try c.decodeIfPresent(Platform.self, forKey: .embed)
        sdk = try c.decodeIfPresent(String.self, forKey: .sdk)
        table = try c.decodeIfPresent(String.self, forKey: .table)
        tableScan = try c.decodeIfPresent(String.self, forKey: .tableScan)
        mode = try c.decodeIfPresent(ServiceMode.self, forKey: .mode)
        debug = try c.decodeIfPresent(String.self, forKey: .debug)
        parent = try c.decodeIfPresent(String.self, forKey: .parent)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(token, forKey: .token)
        try c.encodeIfPresent(code, forKey: .code)
        try c.encodeIfPresent(embed, forKey: .embed)
        try c.encodeIfPresent(sdk, forKey: .sdk)
        try c.encodeIfPresent(table, forKey: .table)
        try c.encodeIfPresent(tableScan, forKey: .tableScan)
        try c.encodeIfPresent(mode, forKey: .mode)
        try c.encodeIfPresent(debug, forKey: .debug)
        try c.encodeIfPresent(parent, forKey: .parent)
    }
}

public struct WaiterQuery: Codable, Sendable, Equatable {
    public var key: String?
    public var branch: String?
    public var lang: String?
    public var appearance: String?

    public init(key: String? = nil, branch: String? = nil, lang: String? = nil, appearance: String? = nil) {
        self.key = key
        self.branch = branch
        self.lang = lang
        self.appearance = appearance
    }

    private enum CodingKeys: String, CodingKey {
        case key, branch, lang, appearance
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = try c.decodeIfPresent(String.self, forKey: .key)
        branch = try c.decodeIfPresent(String.self, forKey: .branch)
        lang = try c.decodeIfPresent(String.self, forKey: .lang)
        appearance = try c.decodeIfPresent(String.self, forKey: .appearance)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(key, forKey: .key)
        try c.encodeIfPresent(branch, forKey: .branch)
        try c.encodeIfPresent(lang, forKey: .lang)
        try c.encodeIfPresent(appearance, forKey: .appearance)
    }
}

/// A message from the app to the page. A protocol, not an enum: switch with a default, and a
/// new message type never breaks your build.
public protocol HostMessage: Sendable {
    /// The type as it travels on the bridge.
    var type: String { get }
    var payload: (any Encodable & Sendable)? { get }
}

public struct HostHelloMessage: HostMessage, Equatable {
    public let data: HostHelloData
    public init(data: HostHelloData) { self.data = data }
    public var payload: (any Encodable & Sendable)? { data }
    public var type: String { "host.hello" }
}

public struct IdentityTokenMessage: HostMessage, Equatable {
    public let data: IdentityTokenData
    public init(data: IdentityTokenData) { self.data = data }
    public var payload: (any Encodable & Sendable)? { data }
    public var type: String { "identity.token" }
}

public struct IdentityClearMessage: HostMessage, Equatable {
    public init() {}
    public var payload: (any Encodable & Sendable)? { nil }
    public var type: String { "identity.clear" }
}

public struct ContextMessage: HostMessage, Equatable {
    public let data: ContextData
    public init(data: ContextData) { self.data = data }
    public var payload: (any Encodable & Sendable)? { data }
    public var type: String { "context" }
}

public struct CartSnapshotMessage: HostMessage, Equatable {
    public let data: CartSnapshotData
    public init(data: CartSnapshotData) { self.data = data }
    public var payload: (any Encodable & Sendable)? { data }
    public var type: String { "cart.snapshot" }
}

public struct ThemeMessage: HostMessage, Equatable {
    public let data: ThemeData
    public init(data: ThemeData) { self.data = data }
    public var payload: (any Encodable & Sendable)? { data }
    public var type: String { "theme" }
}

public struct AppearanceMessage: HostMessage, Equatable {
    public let data: Appearance
    public init(data: Appearance) { self.data = data }
    public var payload: (any Encodable & Sendable)? { data }
    public var type: String { "appearance" }
}

public struct TextMessage: HostMessage, Equatable {
    public let data: Text
    public init(data: Text) { self.data = data }
    public var payload: (any Encodable & Sendable)? { data }
    public var type: String { "text" }
}

public struct LocaleMessage: HostMessage, Equatable {
    public let data: LocaleData
    public init(data: LocaleData) { self.data = data }
    public var payload: (any Encodable & Sendable)? { data }
    public var type: String { "locale" }
}

public struct VisibilityMessage: HostMessage, Equatable {
    public let data: VisibilityData
    public init(data: VisibilityData) { self.data = data }
    public var payload: (any Encodable & Sendable)? { data }
    public var type: String { "visibility" }
}

public struct ChatSendMessage: HostMessage, Equatable {
    public let data: ChatSendData
    public init(data: ChatSendData) { self.data = data }
    public var payload: (any Encodable & Sendable)? { data }
    public var type: String { "chat.send" }
}

public struct ChatNewMessage: HostMessage, Equatable {
    public init() {}
    public var payload: (any Encodable & Sendable)? { nil }
    public var type: String { "chat.new" }
}

public struct StartersMessage: HostMessage, Equatable {
    public let data: StartersData
    public init(data: StartersData) { self.data = data }
    public var payload: (any Encodable & Sendable)? { data }
    public var type: String { "starters" }
}

public struct RestrictionsMessage: HostMessage, Equatable {
    public let data: RestrictionsData
    public init(data: RestrictionsData) { self.data = data }
    public var payload: (any Encodable & Sendable)? { data }
    public var type: String { "restrictions" }
}

public struct ReviewRequestMessage: HostMessage, Equatable {
    public let data: ReviewRequestData
    public init(data: ReviewRequestData) { self.data = data }
    public var payload: (any Encodable & Sendable)? { data }
    public var type: String { "review.request" }
}

public struct HostReplyMessage: HostMessage, Equatable {
    public let data: Reply
    public init(data: Reply) { self.data = data }
    public var payload: (any Encodable & Sendable)? { data }
    public var type: String { "reply" }
}

/// A message of a type this version does not know. Ignore it.
public struct UnknownHostMessage: HostMessage, Equatable {
    public let type: String
    public var payload: (any Encodable & Sendable)? { nil }
}

/// Reads one message: nil when it is not an envelope v1 or its data does not match the contract.
public func parseHostMessage(_ raw: String) -> Envelope<any HostMessage>? {
    let decoder = JSONDecoder()
    guard let json = raw.data(using: .utf8),
          let head = try? decoder.decode(Head.self, from: json),
          head.v == TamrContract.bridgeVersion
    else { return nil }
    do {
        let message: any HostMessage
        switch head.type {
        case "host.hello":
            message = HostHelloMessage(data: try decoder.decode(Box<HostHelloData>.self, from: json).data)
        case "identity.token":
            message = IdentityTokenMessage(data: try decoder.decode(Box<IdentityTokenData>.self, from: json).data)
        case "identity.clear":
            message = IdentityClearMessage()
        case "context":
            message = ContextMessage(data: try decoder.decode(Box<ContextData>.self, from: json).data)
        case "cart.snapshot":
            message = CartSnapshotMessage(data: try decoder.decode(Box<CartSnapshotData>.self, from: json).data)
        case "theme":
            message = ThemeMessage(data: try decoder.decode(Box<ThemeData>.self, from: json).data)
        case "appearance":
            message = AppearanceMessage(data: try decoder.decode(Box<Appearance>.self, from: json).data)
        case "text":
            message = TextMessage(data: try decoder.decode(Box<Text>.self, from: json).data)
        case "locale":
            message = LocaleMessage(data: try decoder.decode(Box<LocaleData>.self, from: json).data)
        case "visibility":
            message = VisibilityMessage(data: try decoder.decode(Box<VisibilityData>.self, from: json).data)
        case "chat.send":
            message = ChatSendMessage(data: try decoder.decode(Box<ChatSendData>.self, from: json).data)
        case "chat.new":
            message = ChatNewMessage()
        case "starters":
            message = StartersMessage(data: try decoder.decode(Box<StartersData>.self, from: json).data)
        case "restrictions":
            message = RestrictionsMessage(data: try decoder.decode(Box<RestrictionsData>.self, from: json).data)
        case "review.request":
            message = ReviewRequestMessage(data: try decoder.decode(Box<ReviewRequestData>.self, from: json).data)
        case "reply":
            message = HostReplyMessage(data: try decoder.decode(Box<Reply>.self, from: json).data)
        default:
            message = UnknownHostMessage(type: head.type)
        }
        return Envelope(id: head.id, ts: head.ts, replyTo: head.replyTo, message: message, raw: raw)
    } catch {
        return nil
    }
}

/// Writes one message as an envelope v1.
public func encodeHostMessage(_ message: any HostMessage, id: String, ts: Int, replyTo: String? = nil) throws -> String {
    let out = Out(v: TamrContract.bridgeVersion, id: id, type: message.type, ts: ts, data: AnyData(value: message.payload), replyTo: replyTo)
    let data = try JSONEncoder().encode(out)
    guard let text = String(data: data, encoding: .utf8) else { throw ContractError(description: "Not UTF-8") }
    return text
}

/// A message from the page to the app. A protocol, not an enum: switch with a default, and a
/// new message type never breaks your build.
public protocol PageMessage: Sendable {
    /// The type as it travels on the bridge.
    var type: String { get }
    var payload: (any Encodable & Sendable)? { get }
}

public struct ReadyMessage: PageMessage, Equatable {
    public let data: ReadyData
    public init(data: ReadyData) { self.data = data }
    public var payload: (any Encodable & Sendable)? { data }
    public var type: String { "ready" }
}

public struct PaintedMessage: PageMessage, Equatable {
    public init() {}
    public var payload: (any Encodable & Sendable)? { nil }
    public var type: String { "painted" }
}

public struct TimingMessage: PageMessage, Equatable {
    public let data: OpenTiming
    public init(data: OpenTiming) { self.data = data }
    public var payload: (any Encodable & Sendable)? { data }
    public var type: String { "timing" }
}

public struct StateMessage: PageMessage, Equatable {
    public let data: StateData
    public init(data: StateData) { self.data = data }
    public var payload: (any Encodable & Sendable)? { data }
    public var type: String { "state" }
}

public struct IdentityRequestMessage: PageMessage, Equatable {
    public let data: IdentityRequestData
    public init(data: IdentityRequestData) { self.data = data }
    public var payload: (any Encodable & Sendable)? { data }
    public var type: String { "identity.request" }
}

public struct CartAddMessage: PageMessage, Equatable {
    public let data: CartChange
    public init(data: CartChange) { self.data = data }
    public var payload: (any Encodable & Sendable)? { data }
    public var type: String { "cart.add" }
}

public struct CartUpdateMessage: PageMessage, Equatable {
    public let data: CartChange
    public init(data: CartChange) { self.data = data }
    public var payload: (any Encodable & Sendable)? { data }
    public var type: String { "cart.update" }
}

public struct CartRemoveMessage: PageMessage, Equatable {
    public let data: CartChange
    public init(data: CartChange) { self.data = data }
    public var payload: (any Encodable & Sendable)? { data }
    public var type: String { "cart.remove" }
}

public struct CheckoutMessage: PageMessage, Equatable {
    public let data: CheckoutData
    public init(data: CheckoutData) { self.data = data }
    public var payload: (any Encodable & Sendable)? { data }
    public var type: String { "checkout" }
}

public struct OpenDishMessage: PageMessage, Equatable {
    public let data: OpenDish
    public init(data: OpenDish) { self.data = data }
    public var payload: (any Encodable & Sendable)? { data }
    public var type: String { "open_dish" }
}

public struct CloseMessage: PageMessage, Equatable {
    public init() {}
    public var payload: (any Encodable & Sendable)? { nil }
    public var type: String { "close" }
}

public struct LogMessage: PageMessage, Equatable {
    public let data: LogData
    public init(data: LogData) { self.data = data }
    public var payload: (any Encodable & Sendable)? { data }
    public var type: String { "log" }
}

public struct OrderPlacedMessage: PageMessage, Equatable {
    public let data: OrderPlaced
    public init(data: OrderPlaced) { self.data = data }
    public var payload: (any Encodable & Sendable)? { data }
    public var type: String { "order.placed" }
}

public struct PaymentOpenMessage: PageMessage, Equatable {
    public let data: PaymentOpen
    public init(data: PaymentOpen) { self.data = data }
    public var payload: (any Encodable & Sendable)? { data }
    public var type: String { "payment.open" }
}

public struct PaymentCompletedMessage: PageMessage, Equatable {
    public let data: PaymentCompleted
    public init(data: PaymentCompleted) { self.data = data }
    public var payload: (any Encodable & Sendable)? { data }
    public var type: String { "payment.completed" }
}

public struct BookingMadeMessage: PageMessage, Equatable {
    public let data: Booking
    public init(data: Booking) { self.data = data }
    public var payload: (any Encodable & Sendable)? { data }
    public var type: String { "booking.made" }
}

public struct BookingChangedMessage: PageMessage, Equatable {
    public let data: Booking
    public init(data: Booking) { self.data = data }
    public var payload: (any Encodable & Sendable)? { data }
    public var type: String { "booking.changed" }
}

public struct WaiterCalledMessage: PageMessage, Equatable {
    public let data: WaiterCalled
    public init(data: WaiterCalled) { self.data = data }
    public var payload: (any Encodable & Sendable)? { data }
    public var type: String { "waiter.called" }
}

public struct PageReplyMessage: PageMessage, Equatable {
    public let data: Reply
    public init(data: Reply) { self.data = data }
    public var payload: (any Encodable & Sendable)? { data }
    public var type: String { "reply" }
}

/// A message of a type this version does not know. Ignore it.
public struct UnknownPageMessage: PageMessage, Equatable {
    public let type: String
    public var payload: (any Encodable & Sendable)? { nil }
}

/// Reads one message: nil when it is not an envelope v1 or its data does not match the contract.
public func parsePageMessage(_ raw: String) -> Envelope<any PageMessage>? {
    let decoder = JSONDecoder()
    guard let json = raw.data(using: .utf8),
          let head = try? decoder.decode(Head.self, from: json),
          head.v == TamrContract.bridgeVersion
    else { return nil }
    do {
        let message: any PageMessage
        switch head.type {
        case "ready":
            message = ReadyMessage(data: try decoder.decode(Box<ReadyData>.self, from: json).data)
        case "painted":
            message = PaintedMessage()
        case "timing":
            message = TimingMessage(data: try decoder.decode(Box<OpenTiming>.self, from: json).data)
        case "state":
            message = StateMessage(data: try decoder.decode(Box<StateData>.self, from: json).data)
        case "identity.request":
            message = IdentityRequestMessage(data: try decoder.decode(Box<IdentityRequestData>.self, from: json).data)
        case "cart.add":
            message = CartAddMessage(data: try decoder.decode(Box<CartChange>.self, from: json).data)
        case "cart.update":
            message = CartUpdateMessage(data: try decoder.decode(Box<CartChange>.self, from: json).data)
        case "cart.remove":
            message = CartRemoveMessage(data: try decoder.decode(Box<CartChange>.self, from: json).data)
        case "checkout":
            message = CheckoutMessage(data: try decoder.decode(Box<CheckoutData>.self, from: json).data)
        case "open_dish":
            message = OpenDishMessage(data: try decoder.decode(Box<OpenDish>.self, from: json).data)
        case "close":
            message = CloseMessage()
        case "log":
            message = LogMessage(data: try decoder.decode(Box<LogData>.self, from: json).data)
        case "order.placed":
            message = OrderPlacedMessage(data: try decoder.decode(Box<OrderPlaced>.self, from: json).data)
        case "payment.open":
            message = PaymentOpenMessage(data: try decoder.decode(Box<PaymentOpen>.self, from: json).data)
        case "payment.completed":
            message = PaymentCompletedMessage(data: try decoder.decode(Box<PaymentCompleted>.self, from: json).data)
        case "booking.made":
            message = BookingMadeMessage(data: try decoder.decode(Box<Booking>.self, from: json).data)
        case "booking.changed":
            message = BookingChangedMessage(data: try decoder.decode(Box<Booking>.self, from: json).data)
        case "waiter.called":
            message = WaiterCalledMessage(data: try decoder.decode(Box<WaiterCalled>.self, from: json).data)
        case "reply":
            message = PageReplyMessage(data: try decoder.decode(Box<Reply>.self, from: json).data)
        default:
            message = UnknownPageMessage(type: head.type)
        }
        return Envelope(id: head.id, ts: head.ts, replyTo: head.replyTo, message: message, raw: raw)
    } catch {
        return nil
    }
}

/// Writes one message as an envelope v1.
public func encodePageMessage(_ message: any PageMessage, id: String, ts: Int, replyTo: String? = nil) throws -> String {
    let out = Out(v: TamrContract.bridgeVersion, id: id, type: message.type, ts: ts, data: AnyData(value: message.payload), replyTo: replyTo)
    let data = try JSONEncoder().encode(out)
    guard let text = String(data: data, encoding: .utf8) else { throw ContractError(description: "Not UTF-8") }
    return text
}
