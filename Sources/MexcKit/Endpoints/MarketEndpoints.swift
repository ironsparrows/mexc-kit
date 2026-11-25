import Foundation

/// The live ``MexcFutures/MarketAPI``.
struct MarketEndpoints: MexcFutures.MarketAPI {
    let rest: RESTClient

    // MARK: - Endpoints

    func serverTime() async throws -> Date {
        try await rest.send(.serverTime).date
    }

    func contracts() async throws -> [MexcFutures.Contract] {
        try await rest.send(.get("/api/v1/contract/detail/country"))
    }

    func contract(_ symbol: MexcFutures.Symbol) async throws -> MexcFutures.Contract {
        try await rest.send(.get("/api/v1/contract/detail/country", query: ["symbol": symbol.rawValue]))
    }

    func transferableAssets() async throws -> [String] {
        try await rest.send(.get("/api/v1/contract/support_currencies"))
    }

    func orderBook(_ symbol: MexcFutures.Symbol, limit: Int?) async throws -> MexcFutures.OrderBook {
        try await rest.send(.get("/api/v1/contract/depth/\(symbol.rawValue)", query: ["limit": limit.map(String.init)]))
    }

    func orderBookChanges(_ symbol: MexcFutures.Symbol, limit: Int) async throws -> [MexcFutures.OrderBook.Change] {
        let changes: [MexcFutures.OrderBook.Change] = try await rest.send(
            .get("/api/v1/contract/depth_commits/\(symbol.rawValue)/\(limit)")
        )
        // MEXC sends the newest change first.
        return changes.sorted { $0.version < $1.version }
    }

    func indexPrice(_ symbol: MexcFutures.Symbol) async throws -> MexcFutures.PriceSnapshot {
        let response: IndexPrice = try await rest.send(.get("/api/v1/contract/index_price/\(symbol.rawValue)"))
        return .init(symbol: response.symbol, price: response.indexPrice, time: response.timestamp.date)
    }

    func fairPrice(_ symbol: MexcFutures.Symbol) async throws -> MexcFutures.PriceSnapshot {
        let response: FairPrice = try await rest.send(.get("/api/v1/contract/fair_price/\(symbol.rawValue)"))
        return .init(symbol: response.symbol, price: response.fairPrice, time: response.timestamp.date)
    }

    func fundingRate(_ symbol: MexcFutures.Symbol) async throws -> MexcFutures.FundingRate {
        try await rest.send(.get("/api/v1/contract/funding_rate/\(symbol.rawValue)"))
    }

    func fundingRates() async throws -> [MexcFutures.FundingRate] {
        // Without a symbol the path keeps its trailing slash, and MEXC answers with every market.
        try await rest.send(.get("/api/v1/contract/funding_rate/"))
    }

    func fundingRateHistory(
        _ symbol: MexcFutures.Symbol, page: MexcFutures.PageRequest
    ) async throws -> MexcFutures.Page<MexcFutures.FundingRate.Settlement> {
        try await rest.send(.get("/api/v1/contract/funding_rate/history", query: query(symbol, page)))
    }

    func candles(
        _ symbol: MexcFutures.Symbol, interval: MexcFutures.Candle.Interval, start: Date?, end: Date?,
        price: MexcFutures.CandlePrice
    ) async throws -> [MexcFutures.Candle] {
        let path =
            switch price {
            case .last: "/api/v1/contract/kline/\(symbol.rawValue)"
            case .index: "/api/v1/contract/kline/index_price/\(symbol.rawValue)"
            case .fair: "/api/v1/contract/kline/fair_price/\(symbol.rawValue)"
            }
        let columns: CandleColumns = try await rest.send(
            .get(
                path,
                query: [
                    "interval": interval.rawValue,
                    "start": start.map(Self.seconds),
                    "end": end.map(Self.seconds),
                ]))
        return try columns.candles()
    }

    func deals(_ symbol: MexcFutures.Symbol, limit: Int?) async throws -> [MexcFutures.Deal] {
        try await rest.send(.get("/api/v1/contract/deals/\(symbol.rawValue)", query: ["limit": limit.map(String.init)]))
    }

    func ticker(_ symbol: MexcFutures.Symbol) async throws -> MexcFutures.Ticker {
        try await rest.send(.get("/api/v1/contract/ticker", query: ["symbol": symbol.rawValue]))
    }

    func tickers() async throws -> [MexcFutures.Ticker] {
        try await rest.send(.get("/api/v1/contract/ticker"))
    }

    func insuranceFund(_ symbol: MexcFutures.Symbol) async throws -> MexcFutures.InsuranceFund {
        try await rest.send(.get("/api/v1/contract/risk_reverse/\(symbol.rawValue)"))
    }

    func insuranceFundHistory(
        _ symbol: MexcFutures.Symbol, page: MexcFutures.PageRequest
    ) async throws -> MexcFutures.Page<MexcFutures.InsuranceFund> {
        try await rest.send(.get("/api/v1/contract/risk_reverse/history", query: query(symbol, page)))
    }

    private func query(_ symbol: MexcFutures.Symbol, _ page: MexcFutures.PageRequest) -> KeyValuePairs<String, String?> {
        ["symbol": symbol.rawValue, "page_num": String(page.number), "page_size": String(page.size)]
    }

    /// Whole seconds since 1970, rounded down, as candle requests take them.
    private static func seconds(_ date: Date) -> String {
        String(Int64(date.timeIntervalSince1970.rounded(.down)))
    }
}

// MARK: - Wire

private struct IndexPrice: Decodable, Sendable {
    let symbol: MexcFutures.Symbol
    let indexPrice: Decimal
    let timestamp: MillisecondTimestamp
}

private struct FairPrice: Decodable, Sendable {
    let symbol: MexcFutures.Symbol
    let fairPrice: Decimal
    let timestamp: MillisecondTimestamp
}

/// Candles as MEXC sends them: one array per field, the same index across arrays being one candle.
private struct CandleColumns: Decodable, Sendable {
    let time: [SecondTimestamp]
    let open: [Decimal]
    let high: [Decimal]
    let low: [Decimal]
    let close: [Decimal]
    let vol: [Decimal]
    let amount: [Decimal]

    func candles() throws -> [MexcFutures.Candle] {
        let counts = [open.count, high.count, low.count, close.count, vol.count, amount.count]
        guard counts.allSatisfy({ $0 == time.count }) else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: [], debugDescription: "Candle columns differ in length: \(time.count) times, \(counts)"
                ))
        }
        return time.indices.map { index in
            MexcFutures.Candle(
                time: time[index].date,
                open: open[index], high: high[index], low: low[index], close: close[index],
                volume: vol[index], turnover: amount[index]
            )
        }
    }
}
