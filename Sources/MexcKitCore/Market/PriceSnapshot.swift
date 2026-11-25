public import Foundation

// MARK: - Model

extension MexcFutures {
    /// A market's index or fair price at one time.
    public struct PriceSnapshot: Hashable, Sendable {
        public let symbol: Symbol
        public let price: Decimal
        public let time: Date

        public init(symbol: Symbol, price: Decimal, time: Date) {
            self.symbol = symbol
            self.price = price
            self.time = time
        }
    }
}
