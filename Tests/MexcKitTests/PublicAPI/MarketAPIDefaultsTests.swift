import Foundation
import MexcKit
import Testing

// Only `import MexcKit`, as an app writes: the shorter calls reach an app's own conformer.
extension MexcKitTests {
    @Suite("Market API defaults")
    struct MarketAPIDefaultsTests {
        @Test func `the shorter calls forward to the full requirement`() async throws {
            let recorder = RecordingMarket()
            let market: any MexcFutures.MarketAPI = recorder
            _ = try await market.orderBook("BTC_USDT")
            _ = try await market.candles("BTC_USDT", interval: .oneHour)
            _ = try await market.candles("BTC_USDT", interval: .oneHour, price: .fair)
            _ = try await market.candles("BTC_USDT", interval: .oneHour, from: .distantPast, to: .distantFuture)
            _ = try await market.deals("BTC_USDT")
            _ = try await market.fundingRateHistory("BTC_USDT")
            _ = try await market.insuranceFundHistory("BTC_USDT")
            #expect(
                await recorder.calls.value == [
                    "orderBook nil", "candles nil nil last", "candles nil nil fair", "candles set set last", "deals nil",
                    "fundingRateHistory 1 20", "insuranceFundHistory 1 20",
                ])
        }
    }
}

/// A market that records how each requirement was called.
private struct RecordingMarket: MexcFutures.MarketAPI {
    let calls = Calls()

    actor Calls {
        var value: [String] = []
        func record(_ call: String) { value.append(call) }
    }

    func orderBook(_ symbol: MexcFutures.Symbol, limit: Int?) async throws -> MexcFutures.OrderBook {
        await calls.record("orderBook \(limit.map(String.init) ?? "nil")")
        return .init(asks: [], bids: [], version: 0, time: .distantPast)
    }

    func candles(
        _ symbol: MexcFutures.Symbol, interval: MexcFutures.Candle.Interval, start: Date?, end: Date?,
        price: MexcFutures.CandlePrice
    ) async throws -> [MexcFutures.Candle] {
        await calls.record("candles \(start == nil ? "nil" : "set") \(end == nil ? "nil" : "set") \(price)")
        return []
    }

    func deals(_ symbol: MexcFutures.Symbol, limit: Int?) async throws -> [MexcFutures.Deal] {
        await calls.record("deals \(limit.map(String.init) ?? "nil")")
        return []
    }

    func fundingRateHistory(
        _ symbol: MexcFutures.Symbol, page: MexcFutures.PageRequest
    ) async throws -> MexcFutures.Page<MexcFutures.FundingRate.Settlement> {
        await calls.record("fundingRateHistory \(page.number) \(page.size)")
        return .init(items: [], currentPage: 1, pageSize: 20, totalCount: 0, totalPages: 0)
    }

    func insuranceFundHistory(
        _ symbol: MexcFutures.Symbol, page: MexcFutures.PageRequest
    ) async throws -> MexcFutures.Page<MexcFutures.InsuranceFund> {
        await calls.record("insuranceFundHistory \(page.number) \(page.size)")
        return .init(items: [], currentPage: 1, pageSize: 20, totalCount: 0, totalPages: 0)
    }

    func serverTime() async throws -> Date { .distantPast }
    func contracts() async throws -> [MexcFutures.Contract] { [] }
    func contract(_ symbol: MexcFutures.Symbol) async throws -> MexcFutures.Contract { throw CancellationError() }
    func transferableAssets() async throws -> [String] { [] }
    func orderBookChanges(_ symbol: MexcFutures.Symbol, limit: Int) async throws -> [MexcFutures.OrderBook.Change] { [] }
    func indexPrice(_ symbol: MexcFutures.Symbol) async throws -> MexcFutures.PriceSnapshot { throw CancellationError() }
    func fairPrice(_ symbol: MexcFutures.Symbol) async throws -> MexcFutures.PriceSnapshot { throw CancellationError() }
    func fundingRate(_ symbol: MexcFutures.Symbol) async throws -> MexcFutures.FundingRate { throw CancellationError() }
    func fundingRates() async throws -> [MexcFutures.FundingRate] { [] }
    func ticker(_ symbol: MexcFutures.Symbol) async throws -> MexcFutures.Ticker { throw CancellationError() }
    func tickers() async throws -> [MexcFutures.Ticker] { [] }
    func insuranceFund(_ symbol: MexcFutures.Symbol) async throws -> MexcFutures.InsuranceFund { throw CancellationError() }
}
