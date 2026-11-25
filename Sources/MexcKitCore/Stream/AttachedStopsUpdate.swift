// MARK: - Model

extension MexcFutures {
    /// A change to the take-profit and stop-loss prices an order carries, as MEXC pushes it.
    public struct AttachedStopsUpdate: Hashable, Sendable {
        /// The order that carries them.
        public let order: OrderID
        public let symbol: Symbol
        /// `nil` when the order has no take-profit.
        public let takeProfit: AttachedStop?
        /// `nil` when the order has no stop-loss.
        public let stopLoss: AttachedStop?

        public init(order: OrderID, symbol: Symbol, takeProfit: AttachedStop?, stopLoss: AttachedStop?) {
            self.order = order
            self.symbol = symbol
            self.takeProfit = takeProfit
            self.stopLoss = stopLoss
        }
    }
}
