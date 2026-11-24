public import Foundation

// MARK: - Model

extension MexcFutures {
    /// A change to the futures account's holdings of one asset, as MEXC pushes it.
    ///
    /// It has fewer values than a ``Balance``: MEXC's push leaves out the cash balance, the equity
    /// and the unrealized profit. Read ``AccountAPI/balance(_:)`` for those.
    public struct BalanceUpdate: Hashable, Sendable {
        /// The asset, such as `"USDT"`.
        public let asset: String
        /// The balance free to use, in MEXC's words "currently available".
        public let available: Decimal
        /// The balance held by pending orders.
        public let frozen: Decimal
        /// The margin held by open positions.
        public let positionMargin: Decimal
        /// MEXC's trial bonus; `nil` when the push leaves it out.
        public let bonus: Decimal?

        public init(asset: String, available: Decimal, frozen: Decimal, positionMargin: Decimal, bonus: Decimal?) {
            self.asset = asset
            self.available = available
            self.frozen = frozen
            self.positionMargin = positionMargin
            self.bonus = bonus
        }
    }
}
