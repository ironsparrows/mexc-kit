public import Foundation

// MARK: - Model

extension MexcFutures {
    /// When a plan order triggers: once the watched price reaches ``price`` from the side ``condition``
    /// names.
    public struct Trigger: Hashable, Sendable {
        public let price: Decimal
        public let condition: TriggerCondition
        /// The price MEXC watches.
        public let source: PriceSource

        public init(price: Decimal, condition: TriggerCondition, source: PriceSource = .last) {
            self.price = price
            self.condition = condition
            self.source = source
        }
    }
}
