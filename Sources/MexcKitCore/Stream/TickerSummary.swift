public import Foundation

// MARK: - Model

extension MexcFutures {
    /// One market's prices and statistics in MEXC's all-market ticker stream.
    ///
    /// It has fewer values than a ``Ticker``: MEXC's all-market push leaves out the best bid and ask,
    /// the funding rate, the open interest and the day's change in price.
    public struct TickerSummary: Hashable, Sendable {
        public let symbol: Symbol
        public let lastPrice: Decimal
        public let indexPrice: Decimal
        public let fairPrice: Decimal
        public let high24h: Decimal
        public let low24h: Decimal
        /// The volume traded in the last 24 hours, in contracts.
        public let volume24h: Decimal
        /// The value traded in the last 24 hours, in the quote asset.
        public let turnover24h: Decimal
        /// The change of the last price since the day began at 00:00 UTC+8, MEXC's trading day, as a
        /// fraction of the day's opening price: `-0.0393` is −3.93 %.
        public let dayChangeRate: Decimal
        /// The highest price a buy order may have.
        public let maximumBidPrice: Decimal
        /// The lowest price a sell order may have.
        public let minimumAskPrice: Decimal
        public let time: Date

        public init(
            symbol: Symbol, lastPrice: Decimal, indexPrice: Decimal, fairPrice: Decimal, high24h: Decimal,
            low24h: Decimal, volume24h: Decimal, turnover24h: Decimal, dayChangeRate: Decimal,
            maximumBidPrice: Decimal, minimumAskPrice: Decimal, time: Date
        ) {
            self.symbol = symbol
            self.lastPrice = lastPrice
            self.indexPrice = indexPrice
            self.fairPrice = fairPrice
            self.high24h = high24h
            self.low24h = low24h
            self.volume24h = volume24h
            self.turnover24h = turnover24h
            self.dayChangeRate = dayChangeRate
            self.maximumBidPrice = maximumBidPrice
            self.minimumAskPrice = minimumAskPrice
            self.time = time
        }
    }
}
