public import Foundation

// MARK: - Model

extension MexcFutures {
    /// An asset that futures fees can be deducted from.
    public struct FeeDeductionAsset: Hashable, Sendable {
        /// The asset fees are deducted from, such as `"MX"`: MEXC's "deduction coin".
        public let asset: String
        /// The asset the fees are settled in, such as `"USDT"`.
        public let settlementAsset: String
        /// MEXC's "discount ratio", as MEXC reports it.
        public let discountRatio: Decimal

        public init(asset: String, settlementAsset: String, discountRatio: Decimal) {
            self.asset = asset
            self.settlementAsset = settlementAsset
            self.discountRatio = discountRatio
        }
    }
}

// MARK: - Wire

extension MexcFutures.FeeDeductionAsset: Decodable {
    private enum CodingKeys: String, CodingKey {
        case deductCoin, settleCoin, discountRatio
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        asset = try container.decode(String.self, forKey: .deductCoin)
        settlementAsset = try container.decode(String.self, forKey: .settleCoin)
        discountRatio = try container.decimal(forKey: .discountRatio)
    }
}
