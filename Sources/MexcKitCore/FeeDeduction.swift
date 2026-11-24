public import Foundation

// MARK: - Model

extension MexcFutures {
    /// The fee of one fill and what was deducted from it.
    ///
    /// The optional properties are in MEXC's documentation but missing from some documented examples;
    /// `nil` means the response didn't include the field.
    public struct FeeDeduction: Hashable, Sendable {
        public let fill: FillID
        public let order: OrderID
        public let symbol: Symbol?
        public let fee: Decimal
        /// The asset the fee is paid in, such as `"USDT"`.
        public let feeAsset: String
        /// What the fee was deducted from.
        public let source: Source
        public let deductedFee: Decimal?
        public let deductedFeeAsset: String?
        public let filledAt: Date

        public init(
            fill: FillID, order: OrderID, symbol: Symbol?, fee: Decimal, feeAsset: String,
            source: Source, deductedFee: Decimal?, deductedFeeAsset: String?, filledAt: Date
        ) {
            self.fill = fill
            self.order = order
            self.symbol = symbol
            self.fee = fee
            self.feeAsset = feeAsset
            self.source = source
            self.deductedFee = deductedFee
            self.deductedFeeAsset = deductedFeeAsset
            self.filledAt = filledAt
        }
    }
}

extension MexcFutures.FeeDeduction {
    /// What a fee was deducted from.
    public struct Source: RawRepresentable, Hashable, Sendable, Codable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let notDeducted = Self(rawValue: 0)
        /// MEXC's MXPOINT deduction.
        public static let mxPoint = Self(rawValue: 1)
        /// MEXC's trial bonus deduction.
        public static let trialBonus = Self(rawValue: 2)
    }
}

// MARK: - Wire

extension MexcFutures.FeeDeduction: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, orderId, symbol, fee, feeCurrency, deductType, deductFee, deductFeeCurrency, timestamp
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fill = try container.decode(MexcFutures.FillID.self, forKey: .id)
        order = try container.decode(MexcFutures.OrderID.self, forKey: .orderId)
        symbol = try container.decodeIfPresent(MexcFutures.Symbol.self, forKey: .symbol)
        fee = try container.decimal(forKey: .fee)
        feeAsset = try container.decode(String.self, forKey: .feeCurrency)
        // Documented as a string; the example sends a number.
        let type = try container.decode(FlexibleString.self, forKey: .deductType).value
        guard let rawType = Int(type) else {
            throw DecodingError.dataCorruptedError(
                forKey: .deductType, in: container, debugDescription: "Not a deduction type: \(type)"
            )
        }
        source = Source(rawValue: rawType)
        deductedFee = try container.decimalIfPresent(forKey: .deductFee)
        deductedFeeAsset = try container.decodeIfPresent(String.self, forKey: .deductFeeCurrency)
        filledAt = try container.millisecondDate(forKey: .timestamp)
    }
}
