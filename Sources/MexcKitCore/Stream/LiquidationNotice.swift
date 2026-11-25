public import Foundation

// MARK: - Model

extension MexcFutures {
    /// MEXC's notice that a position was liquidated, or is close to it.
    ///
    /// MEXC's notice names the market only by its display name, not its symbol, and doesn't name the
    /// position.
    public struct LiquidationNotice: Hashable, Sendable {
        public let kind: Kind
        public let marginMode: MarginMode
        /// The market's English display name, such as `"BTC_USDT PERPETUAL"`; `nil` when the notice
        /// leaves it out.
        public let marketName: String?
        /// Whether the account uses MEXC's multi-asset mode.
        public let isMultiAssetMode: Bool
        /// `nil` when the notice leaves it out.
        public let marginRatio: Decimal?

        public init(
            kind: Kind, marginMode: MarginMode, marketName: String?, isMultiAssetMode: Bool, marginRatio: Decimal?
        ) {
            self.kind = kind
            self.marginMode = marginMode
            self.marketName = marketName
            self.isMultiAssetMode = isMultiAssetMode
            self.marginRatio = marginRatio
        }
    }
}

// MARK: - Kind

extension MexcFutures.LiquidationNotice {
    /// Whether a position was liquidated or is close to it.
    public struct Kind: RawRepresentable, Hashable, Sendable, Codable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let liquidation = Self(rawValue: 1)
        public static let warning = Self(rawValue: 2)
    }
}
