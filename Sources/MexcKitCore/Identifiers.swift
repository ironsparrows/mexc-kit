extension MexcFutures {
    /// A futures market's symbol, such as `"BTC_USDT"`.
    public struct Symbol: RawRepresentable, Hashable, Sendable, Codable, ExpressibleByStringLiteral,
        CustomStringConvertible
    {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(stringLiteral value: String) { rawValue = value }
        public var description: String { rawValue }
    }

    /// An order's ID, assigned by MEXC.
    ///
    /// Decodes from a JSON number or a string, which MEXC's responses use for the same ID, and
    /// encodes as a string.
    public struct OrderID: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(from decoder: any Decoder) throws { rawValue = try FlexibleString(from: decoder).value }
        public var description: String { rawValue }
    }

    /// An order ID the app chooses when it places an order, at most 32 characters.
    ///
    /// MEXC rejects a longer one with ``MexcError/Code/externalOrderIDTooLong``.
    public struct ExternalOrderID: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(from decoder: any Decoder) throws { rawValue = try FlexibleString(from: decoder).value }
        public var description: String { rawValue }
    }

    /// A position's ID, assigned by MEXC. Decodes from a JSON number or a string.
    public struct PositionID: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(from decoder: any Decoder) throws { rawValue = try FlexibleString(from: decoder).value }
        public var description: String { rawValue }
    }

    /// A plan order's ID, assigned by MEXC. Decodes from a JSON number or a string.
    public struct PlanOrderID: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(from decoder: any Decoder) throws { rawValue = try FlexibleString(from: decoder).value }
        public var description: String { rawValue }
    }

    /// A stop order's ID, assigned by MEXC. Decodes from a JSON number or a string.
    public struct StopOrderID: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(from decoder: any Decoder) throws { rawValue = try FlexibleString(from: decoder).value }
        public var description: String { rawValue }
    }

    /// A trailing order's ID, assigned by MEXC. Decodes from a JSON number or a string.
    public struct TrailingOrderID: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(from decoder: any Decoder) throws { rawValue = try FlexibleString(from: decoder).value }
        public var description: String { rawValue }
    }
}
