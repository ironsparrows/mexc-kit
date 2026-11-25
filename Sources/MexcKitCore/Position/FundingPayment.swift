public import Foundation

// MARK: - Model

extension MexcFutures {
    /// The funding one position paid or received at one settlement.
    public struct FundingPayment: Hashable, Sendable {
        /// MEXC's ID for the payment.
        public let id: String
        public let symbol: Symbol
        public let side: PositionSide
        /// MEXC's "position value".
        public let positionValue: Decimal
        /// The funding amount, signed as MEXC reports it.
        public let amount: Decimal
        /// The funding rate, as MEXC reports it.
        public let rate: Decimal
        public let settledAt: Date

        public init(
            id: String, symbol: Symbol, side: PositionSide, positionValue: Decimal, amount: Decimal, rate: Decimal,
            settledAt: Date
        ) {
            self.id = id
            self.symbol = symbol
            self.side = side
            self.positionValue = positionValue
            self.amount = amount
            self.rate = rate
            self.settledAt = settledAt
        }
    }
}

// MARK: - Wire

extension MexcFutures.FundingPayment: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, symbol, positionType, positionValue, funding, rate, settleTime
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(FlexibleString.self, forKey: .id).value
        symbol = try container.decode(MexcFutures.Symbol.self, forKey: .symbol)
        side = try container.decode(MexcFutures.PositionSide.self, forKey: .positionType)
        positionValue = try container.decimal(forKey: .positionValue)
        amount = try container.decimal(forKey: .funding)
        rate = try container.decimal(forKey: .rate)
        settledAt = try container.millisecondDate(forKey: .settleTime)
    }
}
