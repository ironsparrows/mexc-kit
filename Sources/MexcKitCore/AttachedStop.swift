public import Foundation

extension MexcFutures {
    /// A take-profit or stop-loss price carried by an order, and the price that triggers it.
    public struct AttachedStop: Hashable, Sendable {
        public let price: Decimal
        /// The price MEXC compares with ``price``. MEXC's default is ``PriceSource/last``.
        public let trigger: PriceSource

        public init(price: Decimal, trigger: PriceSource = .last) {
            self.price = price
            self.trigger = trigger
        }
    }
}
