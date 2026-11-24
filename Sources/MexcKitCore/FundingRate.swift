public import Foundation

// MARK: - Model

extension MexcFutures {
    /// A market's current funding rate and when it is next settled.
    public struct FundingRate: Hashable, Sendable {
        public let symbol: Symbol
        /// The rate as a fraction: `0.0001` is 0.01 %.
        public let rate: Decimal
        public let maximumRate: Decimal
        public let minimumRate: Decimal
        /// How often funding is settled.
        public let interval: Duration
        public let nextSettlement: Date
        public let indexPrice: Decimal
        public let fairPrice: Decimal
        public let time: Date

        public init(
            symbol: Symbol, rate: Decimal, maximumRate: Decimal, minimumRate: Decimal, interval: Duration,
            nextSettlement: Date, indexPrice: Decimal, fairPrice: Decimal, time: Date
        ) {
            self.symbol = symbol
            self.rate = rate
            self.maximumRate = maximumRate
            self.minimumRate = minimumRate
            self.interval = interval
            self.nextSettlement = nextSettlement
            self.indexPrice = indexPrice
            self.fairPrice = fairPrice
            self.time = time
        }
    }
}

extension MexcFutures.FundingRate {
    /// The funding rate one past settlement used.
    public struct Settlement: Hashable, Sendable {
        public let symbol: MexcFutures.Symbol
        public let rate: Decimal
        /// How often funding was settled at the time.
        public let interval: Duration
        public let settledAt: Date

        public init(symbol: MexcFutures.Symbol, rate: Decimal, interval: Duration, settledAt: Date) {
            self.symbol = symbol
            self.rate = rate
            self.interval = interval
            self.settledAt = settledAt
        }
    }
}

// MARK: - Wire

extension MexcFutures.FundingRate: Decodable {
    private enum CodingKeys: String, CodingKey {
        case symbol, fundingRate, maxFundingRate, minFundingRate, collectCycle, nextSettleTime, idxPrice, fairPrice
        case timestamp
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        symbol = try container.decode(MexcFutures.Symbol.self, forKey: .symbol)
        rate = try container.decimal(forKey: .fundingRate)
        maximumRate = try container.decimal(forKey: .maxFundingRate)
        minimumRate = try container.decimal(forKey: .minFundingRate)
        interval = .seconds(try container.decode(Int.self, forKey: .collectCycle) * 3600)
        nextSettlement = try container.millisecondDate(forKey: .nextSettleTime)
        indexPrice = try container.decimal(forKey: .idxPrice)
        fairPrice = try container.decimal(forKey: .fairPrice)
        time = try container.millisecondDate(forKey: .timestamp)
    }
}

extension MexcFutures.FundingRate.Settlement: Decodable {
    private enum CodingKeys: String, CodingKey {
        case symbol, fundingRate, collectCycle, settleTime
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        symbol = try container.decode(MexcFutures.Symbol.self, forKey: .symbol)
        rate = try container.decimal(forKey: .fundingRate)
        interval = .seconds(try container.decode(Int.self, forKey: .collectCycle) * 3600)
        settledAt = try container.millisecondDate(forKey: .settleTime)
    }
}
