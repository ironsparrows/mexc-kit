import Foundation
import MexcKitTestSupport
import Testing
@testable import MexcKit

extension MexcKitTests {
    @Suite(
        "Live REST", .tags(.live), .enabled(if: areLiveTestsEnabled, "Set MEXC_API_KEY and MEXC_API_SECRET to run"),
        .timeLimit(.minutes(2))
    )
    struct LiveRESTTests {
        private static let btc: MexcFutures.Symbol = "BTC_USDT"
        private let market = MexcFutures.Client(credentials: LiveTestSettings.credentials).market

        @Test func `the clock synchronizes with MEXC`() async throws {
            let client = MexcFutures.Client(credentials: LiveTestSettings.credentials)
            try await client.synchronizeClock()
            // A wrong unit (seconds for milliseconds) would put MEXC's clock decades away.
            #expect(abs(await client.clock.now().timeIntervalSinceNow) < 60)
            #expect(abs(try await client.market.serverTime().timeIntervalSinceNow) < 60)
        }

        @Test func `contracts decode`() async throws {
            #expect(try await market.contracts().count > 100)
            #expect(try await market.contract(Self.btc).symbol == Self.btc)
            #expect(try await market.transferableAssets().contains("USDT"))
        }

        @Test func `an unknown symbol throws contractNotFound`() async throws {
            let error = try await #require(throws: MexcError.self) { try await market.contract("NOPE_USDT") }
            #expect(error.code == .contractNotFound)
        }

        @Test func `the order book and its changes decode in order`() async throws {
            let book = try await market.orderBook(Self.btc, limit: 5)
            #expect(book.asks.count == 5)
            #expect(book.asks.map(\.price) == book.asks.map(\.price).sorted())
            #expect(book.bids.map(\.price) == book.bids.map(\.price).sorted(by: >))
            let changes = try await market.orderBookChanges(Self.btc, limit: 5)
            #expect(changes.count == 5)
            #expect(changes.map(\.version) == changes.map(\.version).sorted())
        }

        @Test func `prices and funding decode`() async throws {
            #expect(try await market.indexPrice(Self.btc).price > 0)
            #expect(try await market.fairPrice(Self.btc).price > 0)
            #expect(try await market.fundingRate(Self.btc).symbol == Self.btc)
            #expect(try await market.fundingRates().count > 100)
            let history = try await market.fundingRateHistory(Self.btc).items
            #expect(history.count == 20)
            #expect(history.map(\.settledAt) == history.map(\.settledAt).sorted(by: >))
        }

        @Test(arguments: MexcFutures.CandlePrice.allCases)
        func `candles decode oldest first`(price: MexcFutures.CandlePrice) async throws {
            let candles = try await market.candles(Self.btc, interval: .oneHour, price: price)
            #expect(!candles.isEmpty)
            #expect(candles.map(\.time) == candles.map(\.time).sorted())
        }

        @Test func `deals and tickers decode`() async throws {
            let deals = try await market.deals(Self.btc, limit: 5)
            #expect(deals.count == 5)
            #expect(deals.map(\.time) == deals.map(\.time).sorted(by: >))
            #expect(try await market.ticker(Self.btc).symbol == Self.btc)
            #expect(try await market.tickers().count > 100)
        }

        @Test func `the insurance fund decodes newest first`() async throws {
            #expect(try await market.insuranceFund(Self.btc).balance > 0)
            let history = try await market.insuranceFundHistory(Self.btc).items
            #expect(history.count == 20)
            #expect(history.map(\.time) == history.map(\.time).sorted(by: >))
        }
    }
}
