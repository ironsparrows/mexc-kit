public import Foundation

// MARK: - Model

extension MexcFutures {
    /// A spot fee discount that applies to futures fees, and its levels.
    ///
    /// MEXC's list of contract IDs excluded from the discount isn't exposed: contracts are identified
    /// by symbol in this SDK.
    public struct FeeDiscount: Hashable, Sendable {
        /// MEXC's "deduction currency", such as `"MX"`.
        public let asset: String
        public let isEnabled: Bool
        public let levels: [Level]

        public init(asset: String, isEnabled: Bool, levels: [Level]) {
            self.asset = asset
            self.isEnabled = isEnabled
            self.levels = levels
        }
    }
}

extension MexcFutures.FeeDiscount {
    /// One discount level.
    public struct Level: Hashable, Sendable {
        public let number: Int
        /// MEXC's `volMin` to `volMax`. MEXC doesn't document their unit.
        public let bounds: ClosedRange<Decimal>
        /// MEXC's `day`.
        public let days: Int
        /// The discount, as MEXC reports it.
        public let discount: Decimal

        public init(number: Int, bounds: ClosedRange<Decimal>, days: Int, discount: Decimal) {
            self.number = number
            self.bounds = bounds
            self.days = days
            self.discount = discount
        }
    }
}

// MARK: - Wire

extension MexcFutures.FeeDiscount: Decodable {
    private enum CodingKeys: String, CodingKey {
        case currency, state, discountConfig
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        asset = try container.decode(String.self, forKey: .currency)
        isEnabled = try container.decode(String.self, forKey: .state) == "ENABLED"
        // MEXC sends the levels as JSON inside a string.
        let levels = try container.decodeIfPresent(String.self, forKey: .discountConfig) ?? ""
        do {
            self.levels = levels.isEmpty ? [] : try JSONDecoder().decode([Level].self, from: Data(levels.utf8))
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .discountConfig, in: container, debugDescription: "Not a list of discount levels: \(error)"
            )
        }
    }
}

extension MexcFutures.FeeDiscount.Level: Decodable {
    private enum CodingKeys: String, CodingKey {
        case level, volMin, volMax, day, discount
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        number = try container.decode(Int.self, forKey: .level)
        let minimum = try container.decimal(forKey: .volMin)
        let maximum = try container.decimal(forKey: .volMax)
        guard minimum <= maximum else {
            throw DecodingError.dataCorruptedError(
                forKey: .volMax, in: container, debugDescription: "volMax \(maximum) is below volMin \(minimum)"
            )
        }
        bounds = minimum...maximum
        days = try container.decode(Int.self, forKey: .day)
        discount = try container.decimal(forKey: .discount)
    }
}
