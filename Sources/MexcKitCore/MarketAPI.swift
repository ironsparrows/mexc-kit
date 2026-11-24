public import Foundation

// MARK: - Protocol

extension MexcFutures {
    /// Public market data: contracts, prices, order books, candles, trades, funding and insurance.
    ///
    /// None of these requests needs credentials.
    public protocol MarketAPI: Sendable {
        /// MEXC's current time.
        func serverTime() async throws -> Date

        /// Every futures market.
        func contracts() async throws -> [Contract]

        /// One futures market.
        ///
        /// Throws ``MexcError`` with ``MexcError/Code/contractNotFound`` for an unknown symbol, as do
        /// the other requests that take one.
        func contract(_ symbol: Symbol) async throws -> Contract

        /// The assets that can be transferred to and from the futures account.
        func transferableAssets() async throws -> [String]

        /// The order book, with at most `limit` levels a side; `nil` uses MEXC's default.
        func orderBook(_ symbol: Symbol, limit: Int?) async throws -> OrderBook

        /// The last `limit` changes to the order book, oldest first.
        func orderBookChanges(_ symbol: Symbol, limit: Int) async throws -> [OrderBook.Change]

        /// The market's index price, built from prices on its ``Contract/indexSources``.
        func indexPrice(_ symbol: Symbol) async throws -> PriceSnapshot

        /// The market's fair price.
        func fairPrice(_ symbol: Symbol) async throws -> PriceSnapshot

        /// The market's current funding rate.
        func fundingRate(_ symbol: Symbol) async throws -> FundingRate

        /// The funding rates of every market.
        func fundingRates() async throws -> [FundingRate]

        /// Past funding settlements, newest first. Pages hold at most 1,000.
        func fundingRateHistory(_ symbol: Symbol, page: PageRequest) async throws -> Page<FundingRate.Settlement>

        /// Candles of the last traded, index or fair price, oldest first.
        ///
        /// Without `start` and `end`, MEXC returns its most recent candles. A request returns at most
        /// 2,000 candles.
        func candles(
            _ symbol: Symbol, interval: Candle.Interval, start: Date?, end: Date?, price: CandlePrice
        ) async throws -> [Candle]

        /// The most recent trades, newest first: at most `limit`, which is at most 100; `nil` gives 100.
        func deals(_ symbol: Symbol, limit: Int?) async throws -> [Deal]

        /// The market's latest prices and statistics.
        func ticker(_ symbol: Symbol) async throws -> Ticker

        /// The tickers of every market.
        func tickers() async throws -> [Ticker]

        /// The current balance of the market's insurance fund.
        func insuranceFund(_ symbol: Symbol) async throws -> InsuranceFund

        /// Past balances of the market's insurance fund, newest first. Pages hold at most 100.
        func insuranceFundHistory(_ symbol: Symbol, page: PageRequest) async throws -> Page<InsuranceFund>
    }
}

// MARK: - Defaults

extension MexcFutures.MarketAPI {
    /// The order book at MEXC's default depth.
    public func orderBook(_ symbol: MexcFutures.Symbol) async throws -> MexcFutures.OrderBook {
        try await orderBook(symbol, limit: nil)
    }

    /// The most recent candles of the price.
    public func candles(
        _ symbol: MexcFutures.Symbol, interval: MexcFutures.Candle.Interval, price: MexcFutures.CandlePrice = .last
    ) async throws -> [MexcFutures.Candle] {
        try await candles(symbol, interval: interval, start: nil, end: nil, price: price)
    }

    /// The candles of the price from `start` to `end`.
    public func candles(
        _ symbol: MexcFutures.Symbol, interval: MexcFutures.Candle.Interval, from start: Date, to end: Date,
        price: MexcFutures.CandlePrice = .last
    ) async throws -> [MexcFutures.Candle] {
        try await candles(symbol, interval: interval, start: start, end: end, price: price)
    }

    /// The 100 most recent trades.
    public func deals(_ symbol: MexcFutures.Symbol) async throws -> [MexcFutures.Deal] {
        try await deals(symbol, limit: nil)
    }

    /// The first page of past funding settlements.
    public func fundingRateHistory(
        _ symbol: MexcFutures.Symbol
    ) async throws -> MexcFutures.Page<MexcFutures.FundingRate.Settlement> {
        try await fundingRateHistory(symbol, page: .first)
    }

    /// The first page of past insurance fund balances.
    public func insuranceFundHistory(
        _ symbol: MexcFutures.Symbol
    ) async throws -> MexcFutures.Page<MexcFutures.InsuranceFund> {
        try await insuranceFundHistory(symbol, page: .first)
    }
}

// MARK: - Requests

extension MexcFutures {
    // An enum, unlike the wire vocabularies: each case selects one of MEXC's three candle
    // endpoints, so there is no other value to keep.

    /// Which price candles follow.
    public enum CandlePrice: Hashable, Sendable, CaseIterable {
        /// The last traded price.
        case last
        /// The index price.
        case index
        /// The fair price.
        case fair
    }
}
