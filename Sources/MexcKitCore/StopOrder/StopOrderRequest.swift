public import Foundation

// MARK: - Model

extension MexcFutures {
    /// A stop order to place on a position: a take-profit, a stop-loss or both.
    ///
    /// Volumes are in contracts. MEXC requires at least one exit: a request without one throws
    /// ``ClientError/Reason/invalidRequest`` before anything is sent. MEXC checks that the volume and the
    /// volume of the position's other stop orders together stay below what can be closed.
    public struct StopOrderRequest: Hashable, Sendable {
        public let position: PositionID
        public let volume: Decimal
        public let takeProfit: StopOrder.Exit?
        public let stopLoss: StopOrder.Exit?
        /// MEXC's trigger protection.
        public let triggerProtection: Bool

        public init(
            position: PositionID, volume: Decimal, takeProfit: StopOrder.Exit? = nil, stopLoss: StopOrder.Exit? = nil,
            triggerProtection: Bool = false
        ) {
            self.position = position
            self.volume = volume
            self.takeProfit = takeProfit
            self.stopLoss = stopLoss
            self.triggerProtection = triggerProtection
        }
    }
}
