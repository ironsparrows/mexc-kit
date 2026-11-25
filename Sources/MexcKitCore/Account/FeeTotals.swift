public import Foundation

// MARK: - Model

extension MexcFutures {
    /// The fees of the last 30 days. MEXC doesn't document the asset they're counted in.
    public struct FeeTotals: Hashable, Sendable {
        /// The fees paid, to 4 decimals.
        public let paid: Decimal
        /// The fees saved, to 4 decimals.
        public let saved: Decimal

        public init(paid: Decimal, saved: Decimal) {
            self.paid = paid
            self.saved = saved
        }
    }
}

// MARK: - Wire

extension MexcFutures.FeeTotals: Decodable {
    private enum CodingKeys: String, CodingKey {
        case totalFee, saveFee
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        paid = try container.decimal(forKey: .totalFee)
        saved = try container.decimal(forKey: .saveFee)
    }
}
