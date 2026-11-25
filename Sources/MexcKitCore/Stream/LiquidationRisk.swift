public import Foundation

// MARK: - Model

extension MexcFutures {
    /// How close one of the account's positions is to liquidation, as MEXC pushes it when that
    /// changes.
    public struct LiquidationRisk: Hashable, Sendable {
        public let symbol: Symbol
        /// `nil` when the push names no position.
        public let position: PositionID?
        /// `nil` when the push leaves it out.
        public let liquidationPrice: Decimal?
        /// `nil` when the push leaves it out.
        public let marginRatio: Decimal?
        /// The auto-deleveraging rank from 1 to 5; `nil` when the push sends 0.
        public let autoDeleveragingLevel: Int?

        public init(
            symbol: Symbol, position: PositionID?, liquidationPrice: Decimal?, marginRatio: Decimal?,
            autoDeleveragingLevel: Int?
        ) {
            self.symbol = symbol
            self.position = position
            self.liquidationPrice = liquidationPrice
            self.marginRatio = marginRatio
            self.autoDeleveragingLevel = autoDeleveragingLevel
        }
    }
}
