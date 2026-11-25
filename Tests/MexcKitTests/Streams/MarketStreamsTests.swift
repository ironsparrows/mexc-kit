import Foundation
import Testing
@testable import MexcKit

/// Each market stream's subscribe request, and its first value read from a push recorded from
/// MEXC's Protobuf endpoint (`Fixtures/Stream`).
@Suite("Market streams", .timeLimit(.minutes(1)))
struct MarketStreamsTests {
    private let server = FakeWebSocketServer()
    private var streams: Streams { .test(server) }

    @Test func `a ticker decodes from its push`() async throws {
        let ticker = try await first(
            of: streams.ticker("BTC_USDT"), request: #"{"method":"sub.ticker","param":{"symbol":"BTC_USDT"}}"#,
            acknowledgedOn: "ticker", push: "push.ticker.BTC_USDT"
        )
        #expect(ticker.symbol == "BTC_USDT")
        #expect(ticker.lastPrice == Decimal(string: "60391.5"))
        #expect(ticker.bestBid == Decimal(string: "60391.5"))
        #expect(ticker.bestAsk == Decimal(string: "60391.6"))
        #expect(ticker.indexPrice == Decimal(string: "60426.6"))
        #expect(ticker.fairPrice == Decimal(string: "60394.7"))
        #expect(ticker.fundingRate == Decimal(string: "0.000067"))
        #expect(ticker.openInterest == 479_602_232)
        #expect(ticker.high24h == Decimal(string: "64560.9"))
        #expect(ticker.low24h == 59428)
        #expect(ticker.volume24h == 586_251_443)
        #expect(ticker.turnover24h == Decimal(string: "3617868658.53735"))
        #expect(ticker.dayChange == Decimal(string: "-2475.7"))
        #expect(ticker.dayChangeRate == Decimal(string: "-0.0393"))
        #expect(ticker.maximumBidPrice == Decimal(string: "66469.2"))
        #expect(ticker.minimumAskPrice == Decimal(string: "54383.9"))
        #expect(ticker.time == Date(timeIntervalSince1970: 1_795_506_148.097))
    }

    @Test func `every market's ticker summary decodes from the all-market push`() async throws {
        let summaries = try await first(
            of: streams.tickers(), request: #"{"method":"sub.tickers","param":{}}"#,
            acknowledgedOn: "tickers", push: "push.tickers"
        )
        #expect(summaries.count == 1181)
        let bitcoin = try #require(summaries.first { $0.symbol == "BTC_USDT" })
        #expect(bitcoin.lastPrice == Decimal(string: "60389.7"))
        #expect(bitcoin.fairPrice == Decimal(string: "60385.5"))
        #expect(bitcoin.indexPrice == 60417)
        #expect(bitcoin.dayChangeRate == Decimal(string: "-0.0394"))
        #expect(bitcoin.volume24h == 586_236_484)
        #expect(bitcoin.turnover24h == Decimal(string: "3617778321.07449"))
        #expect(bitcoin.maximumBidPrice == Decimal(string: "66458.7"))
        #expect(bitcoin.minimumAskPrice == Decimal(string: "54375.3"))
        #expect(bitcoin.low24h == 59428)
        #expect(bitcoin.high24h == Decimal(string: "64560.9"))
        #expect(bitcoin.time == Date(timeIntervalSince1970: 1_795_506_144.993))
    }

    @Test func `a merged deal has no ID`() async throws {
        let deal = try await first(
            of: streams.deals("BTC_USDT", merged: true),
            request: #"{"method":"sub.deal","param":{"symbol":"BTC_USDT"}}"#,
            acknowledgedOn: "deal", push: "push.deal.BTC_USDT"
        )
        #expect(deal.id == nil)
        #expect(deal.price == Decimal(string: "60391.6"))
        #expect(deal.volume == 792)
        #expect(deal.takerSide == .buy)
        #expect(deal.positionEffect == .mixed)
        #expect(!deal.isSelfTrade)
        #expect(deal.time == Date(timeIntervalSince1970: 1_795_506_146.872))
    }

    @Test func `every trade comes with its ID when deals aren't merged`() async throws {
        let deal = try await first(
            of: streams.deals("ETH_USDT", merged: false),
            request: #"{"method":"sub.deal","param":{"reduce":false,"symbol":"ETH_USDT"}}"#,
            acknowledgedOn: "deal", push: "push.deal.ETH_USDT"
        )
        #expect(deal.id == "17146825672")
        #expect(deal.price == Decimal(string: "1697.71"))
        #expect(deal.volume == 9)
        #expect(deal.takerSide == .sell)
        #expect(deal.isSelfTrade)
    }

    @Test func `an order book change decodes its levels and version`() async throws {
        let change = try await first(
            of: streams.orderBookChanges("BTC_USDT"), request: #"{"method":"sub.depth","param":{"symbol":"BTC_USDT"}}"#,
            acknowledgedOn: "depth", push: "push.depth.BTC_USDT"
        )
        #expect(change.asks == [.init(price: Decimal(string: "60391.6")!, volume: 446_741, orderCount: 1)])
        #expect(change.bids.isEmpty)
        #expect(change.version == 43_829_097_504)
        // The matching engine's time (`cts`), not the push's (`ts`, 2 ms later).
        #expect(change.time == Date(timeIntervalSince1970: 1_795_506_146.872))
    }

    @Test func `order books of a limit MEXC doesn't take throw invalidRequest before subscribing`() async throws {
        let books = Task { [streams] in
            for try await _ in streams.orderBooks("BTC_USDT", limit: 50) {}
        }
        let error = try await #require(throws: MexcFutures.ClientError.self) { try await books.value }
        #expect(error.reason == .invalidRequest)
        #expect(await server.connectAttempts == 0)
    }

    @Test func `an order book of a few levels decodes`() async throws {
        let book = try await first(
            of: streams.orderBooks("SOL_USDT", limit: 5),
            request: #"{"method":"sub.depth.full","param":{"limit":5,"symbol":"SOL_USDT"}}"#,
            acknowledgedOn: "depth.full", push: "push.depth.full.SOL_USDT"
        )
        #expect(book.asks.count == 5)
        #expect(book.bids.count == 5)
        #expect(book.asks.first == .init(price: Decimal(string: "71.53")!, volume: 20674, orderCount: 1))
        #expect(book.version == 16_028_896_953)
        #expect(book.time == Date(timeIntervalSince1970: 1_795_506_147.032))
    }

    @Test func `an order book grouped by step decodes`() async throws {
        let book = try await first(
            of: streams.orderBooks("DOGE_USDT", step: Decimal(string: "0.001")!),
            request: #"{"method":"sub.depth.step","param":{"step":"0.001","symbol":"DOGE_USDT"}}"#,
            acknowledgedOn: "depth.step", push: "push.depth.step.DOGE_USDT"
        )
        #expect(book.asks.count == 25)
        #expect(book.bids.count == 25)
        #expect(book.asks.first == .init(price: Decimal(string: "0.057")!, volume: 5_007_280, orderCount: 132))
        #expect(book.version == 9_005_389_635)
        #expect(book.time == Date(timeIntervalSince1970: 1_795_506_149.747))
    }

    @Test func `a candle decodes with its start in seconds`() async throws {
        let candle = try await first(
            of: streams.candles("BTC_USDT", interval: .oneMinute),
            request: #"{"method":"sub.kline","param":{"interval":"Min1","symbol":"BTC_USDT"}}"#,
            acknowledgedOn: "kline", push: "push.kline.BTC_USDT"
        )
        #expect(candle.time == Date(timeIntervalSince1970: 1_795_506_120))
        #expect(candle.open == Decimal(string: "60383.4"))
        #expect(candle.high == Decimal(string: "60396.8"))
        #expect(candle.low == Decimal(string: "60362.8"))
        #expect(candle.close == Decimal(string: "60391.5"))
        #expect(candle.volume == 360_276)
        #expect(candle.turnover == Decimal(string: "2175623.96616"))
    }

    @Test func `an index price decodes with the push's time`() async throws {
        let price = try await first(
            of: streams.indexPrice("BTC_USDT"), request: #"{"method":"sub.index.price","param":{"symbol":"BTC_USDT"}}"#,
            acknowledgedOn: "index.price", push: "push.index.price.BTC_USDT"
        )
        #expect(price == .init(symbol: "BTC_USDT", price: Decimal(string: "60426.7")!, time: Date(timeIntervalSince1970: 1_795_506_146.416)))
    }

    @Test func `a fair price decodes with the push's time`() async throws {
        let price = try await first(
            of: streams.fairPrice("BTC_USDT"), request: #"{"method":"sub.fair.price","param":{"symbol":"BTC_USDT"}}"#,
            acknowledgedOn: "fair.price", push: "push.fair.price.BTC_USDT"
        )
        #expect(price == .init(symbol: "BTC_USDT", price: 60395, time: Date(timeIntervalSince1970: 1_795_506_146.515)))
    }

    /// Checks the stream's request, acknowledges it, sends `push` and returns the stream's first value.
    private func first<Element: Sendable>(
        of stream: AsyncThrowingStream<Element, any Error>, request: String, acknowledgedOn channel: String,
        push fixture: String
    ) async throws -> Element {
        #expect(await server.nextSent() == request)
        await server.acknowledge(channel)
        try await server.push(fixture)
        var values = stream.makeAsyncIterator()
        let value = try await values.next()
        return try #require(value)
    }
}
