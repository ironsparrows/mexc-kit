public import Foundation

// MARK: - Model

extension MexcFutures {
    /// A change to the account's trial bonus, as MEXC pushes it.
    public struct TrialBonusUpdate: Hashable, Sendable {
        /// The asset, such as `"USDT"`.
        public let asset: String
        /// `nil` when the push leaves it out.
        public let amount: Decimal?
        /// When the bonus expires; `nil` when the push leaves it out.
        public let expiresAt: Date?
        /// MEXC's "whether trial bonus granted".
        public let isGranted: Bool
        /// MEXC's "most recent expiry time"; `nil` when the push sends none.
        public let nearestExpiry: Date?
        /// The amount that expires at ``nearestExpiry``; `nil` when the push sends none.
        public let nearestExpiringAmount: Decimal?

        public init(
            asset: String, amount: Decimal?, expiresAt: Date?, isGranted: Bool, nearestExpiry: Date?,
            nearestExpiringAmount: Decimal?
        ) {
            self.asset = asset
            self.amount = amount
            self.expiresAt = expiresAt
            self.isGranted = isGranted
            self.nearestExpiry = nearestExpiry
            self.nearestExpiringAmount = nearestExpiringAmount
        }
    }
}
