// MARK: - Model

extension MexcFutures {
    /// Which fee reduction applies to the account.
    ///
    /// MEXC applies its spot fee discount when the account has one, and the MX deduction when the account
    /// holds MX for futures.
    public struct DiscountUsage: Hashable, Sendable {
        /// Whether the spot discount fee rate applies.
        public let usesSpotDiscount: Bool
        /// Whether the futures deduction fee rate applies.
        public let usesDeduction: Bool

        public init(usesSpotDiscount: Bool, usesDeduction: Bool) {
            self.usesSpotDiscount = usesSpotDiscount
            self.usesDeduction = usesDeduction
        }
    }
}

// MARK: - Wire

extension MexcFutures.DiscountUsage: Decodable {
    private enum CodingKeys: String, CodingKey {
        case useFeeDiscount, useFeeDeduct
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        usesSpotDiscount = try container.decode(Bool.self, forKey: .useFeeDiscount)
        usesDeduction = try container.decode(Bool.self, forKey: .useFeeDeduct)
    }
}
