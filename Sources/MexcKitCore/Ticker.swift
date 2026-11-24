public import Foundation

// MARK: - Model

extension MexcFutures {
    /// A market's latest prices and 24-hour statistics.
    public struct Ticker: Hashable, Sendable {
        public let symbol: Symbol
        public let lastPrice: Decimal
        /// The highest bid. `nil` when MEXC sends none, as it does for some markets.
        public let bestBid: Decimal?
        /// The lowest ask. `nil` when MEXC sends none, as it does for some markets.
        public let bestAsk: Decimal?
        public let indexPrice: Decimal
        public let fairPrice: Decimal
        public let fundingRate: Decimal
        /// The open interest, in contracts.
        public let openInterest: Decimal
        public let high24h: Decimal
        public let low24h: Decimal
        /// The volume traded in the last 24 hours, in contracts.
        public let volume24h: Decimal
        /// The value traded in the last 24 hours, in the quote asset.
        public let turnover24h: Decimal
        /// The change of the last price since the day began at 00:00 UTC+8, MEXC's trading day.
        public let dayChange: Decimal
        /// ``dayChange`` as a fraction of the day's opening price: `-0.0454` is −4.54 %.
        public let dayChangeRate: Decimal
        /// The highest price a buy order may have.
        public let maximumBidPrice: Decimal
        /// The lowest price a sell order may have.
        public let minimumAskPrice: Decimal
        public let time: Date

        public init(
            symbol: Symbol, lastPrice: Decimal, bestBid: Decimal?, bestAsk: Decimal?, indexPrice: Decimal,
            fairPrice: Decimal, fundingRate: Decimal, openInterest: Decimal, high24h: Decimal, low24h: Decimal,
            volume24h: Decimal, turnover24h: Decimal, dayChange: Decimal, dayChangeRate: Decimal,
            maximumBidPrice: Decimal, minimumAskPrice: Decimal, time: Date
        ) {
            self.symbol = symbol
            self.lastPrice = lastPrice
            self.bestBid = bestBid
            self.bestAsk = bestAsk
            self.indexPrice = indexPrice
            self.fairPrice = fairPrice
            self.fundingRate = fundingRate
            self.openInterest = openInterest
            self.high24h = high24h
            self.low24h = low24h
            self.volume24h = volume24h
            self.turnover24h = turnover24h
            self.dayChange = dayChange
            self.dayChangeRate = dayChangeRate
            self.maximumBidPrice = maximumBidPrice
            self.minimumAskPrice = minimumAskPrice
            self.time = time
        }
    }
}

// MARK: - Wire

extension MexcFutures.Ticker: Decodable {
    private enum CodingKeys: String, CodingKey {
        case symbol, lastPrice, bid1, ask1, indexPrice, fairPrice, fundingRate, holdVol, high24Price, lower24Price
        case volume24, amount24, riseFallValue, riseFallRate, maxBidPrice, minAskPrice, timestamp
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        symbol = try container.decode(MexcFutures.Symbol.self, forKey: .symbol)
        lastPrice = try container.decimal(forKey: .lastPrice)
        bestBid = try container.decimalIfPresent(forKey: .bid1)
        bestAsk = try container.decimalIfPresent(forKey: .ask1)
        indexPrice = try container.decimal(forKey: .indexPrice)
        fairPrice = try container.decimal(forKey: .fairPrice)
        fundingRate = try container.decimal(forKey: .fundingRate)
        openInterest = try container.decimal(forKey: .holdVol)
        high24h = try container.decimal(forKey: .high24Price)
        low24h = try container.decimal(forKey: .lower24Price)
        volume24h = try container.decimal(forKey: .volume24)
        turnover24h = try container.decimal(forKey: .amount24)
        dayChange = try container.decimal(forKey: .riseFallValue)
        dayChangeRate = try container.decimal(forKey: .riseFallRate)
        maximumBidPrice = try container.decimal(forKey: .maxBidPrice)
        minimumAskPrice = try container.decimal(forKey: .minAskPrice)
        time = try container.millisecondDate(forKey: .timestamp)
    }
}
