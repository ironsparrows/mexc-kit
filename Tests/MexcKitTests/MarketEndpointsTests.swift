import Foundation
import Testing
@testable import MexcKit

// Each call against a response recorded from MEXC on 2026-11-24 (IDs replaced): the exact request it
// sends and what it decodes.
@Suite("Market endpoints")
struct MarketEndpointsTests {
    private static let btc: MexcFutures.Symbol = "BTC_USDT"

    @Test func `server time`() async throws {
        let (time, url) = try await call("ping") { try await $0.serverTime() }
        #expect(url == "https://api.mexc.com/api/v1/contract/ping")
        #expect(time == Date(timeIntervalSince1970: 1795514785.849))
    }

    @Test func `one contract`() async throws {
        let (contract, url) = try await call("contract") { try await $0.contract(Self.btc) }
        #expect(url == "https://api.mexc.com/api/v1/contract/detail/country?symbol=BTC_USDT")
        #expect(contract.symbol == Self.btc)
        #expect(contract.displayName == "BTC_USDT PERPETUAL")
        #expect(contract.baseAsset == "BTC")
        #expect(contract.quoteAsset == "USDT")
        #expect(contract.settlementAsset == "USDT")
        #expect(contract.contractSize == Decimal(string: "0.0001"))
        #expect(contract.leverage == 1...500)
        #expect(contract.priceTick == Decimal(string: "0.1"))
        #expect(contract.volumeStep == 1)
        #expect(contract.priceScale == 1)
        #expect(contract.volumeScale == 0)
        #expect(contract.minimumVolume == 1)
        #expect(contract.maximumVolume == 400_000)
        #expect(contract.maximumLimitOrderVolume == 2_500_000)
        #expect(contract.takerFeeRate == Decimal(string: "0.0001"))
        #expect(contract.makerFeeRate == 0)
        #expect(contract.initialMarginRate == Decimal(string: "0.002"))
        #expect(contract.maintenanceMarginRate == Decimal(string: "0.001"))
        #expect(contract.riskLimits.count == 6)
        #expect(contract.riskLimits.first == .init(
            level: 1, maximumVolume: 120_000, maintenanceMarginRate: Decimal(string: "0.001")!,
            initialMarginRate: Decimal(string: "0.002")!, maximumLeverage: 500
        ))
        #expect(contract.marginModes == [.isolated, .cross])
        #expect(contract.state == .enabled)
        #expect(contract.allowsAPITrading)
        #expect(contract.indexSources.contains("BINANCE"))
        #expect(contract.depthSteps == [Decimal(string: "0.1")!, 1, 10, 100])
        #expect(contract.listedAt == Date(timeIntervalSince1970: 1_591_242_684))
    }

    @Test func `every contract`() async throws {
        let (contracts, url) = try await call("contracts") { try await $0.contracts() }
        #expect(url == "https://api.mexc.com/api/v1/contract/detail/country")
        #expect(contracts.map(\.symbol) == ["BTC_USDT", "CYS_USDT", "DANGOTESTOCK_USDT"])
        #expect(contracts[1].riskLimits.isEmpty)
        #expect(contracts[2].marginModes == [.isolated])
    }

    @Test func `transferable assets`() async throws {
        let (assets, url) = try await call("currencies") { try await $0.transferableAssets() }
        #expect(url == "https://api.mexc.com/api/v1/contract/support_currencies")
        #expect(assets.contains("USDT"))
    }

    @Test func `order book`() async throws {
        let (book, url) = try await call("depth") { try await $0.orderBook(Self.btc, limit: 5) }
        #expect(url == "https://api.mexc.com/api/v1/contract/depth/BTC_USDT?limit=5")
        #expect(book.asks.count == 5)
        #expect(book.asks.first == .init(price: Decimal(string: "60007.8")!, volume: 394_872, orderCount: 1))
        #expect(book.bids.first == .init(price: Decimal(string: "60007.7")!, volume: 206_190, orderCount: 2))
        #expect(book.version == 43_833_673_146)
        #expect(book.time == Date(timeIntervalSince1970: 1_795_514_786.801))
    }

    @Test func `order book without a limit`() async throws {
        let (_, url) = try await call("depth") { try await $0.orderBook(Self.btc) }
        #expect(url == "https://api.mexc.com/api/v1/contract/depth/BTC_USDT")
    }

    @Test func `order book changes come oldest first`() async throws {
        let (changes, url) = try await call("depth_commits") { try await $0.orderBookChanges(Self.btc, limit: 3) }
        #expect(url == "https://api.mexc.com/api/v1/contract/depth_commits/BTC_USDT/3")
        #expect(changes.map(\.version) == [43_833_673_147, 43_833_673_148, 43_833_673_149])
        #expect(changes.last?.bids == [.init(price: Decimal(string: "60007.7")!, volume: 206_189, orderCount: 2)])
        #expect(changes.last?.asks == [])
    }

    @Test func `index and fair price`() async throws {
        let (index, indexURL) = try await call("index") { try await $0.indexPrice(Self.btc) }
        let (fair, fairURL) = try await call("fair") { try await $0.fairPrice(Self.btc) }
        #expect(indexURL == "https://api.mexc.com/api/v1/contract/index_price/BTC_USDT")
        #expect(fairURL == "https://api.mexc.com/api/v1/contract/fair_price/BTC_USDT")
        #expect(index == .init(symbol: Self.btc, price: Decimal(string: "60029.2")!, time: Date(timeIntervalSince1970: 1_795_514_788.278)))
        #expect(fair.price == Decimal(string: "60008.3"))
    }

    @Test func `funding rate`() async throws {
        let (rate, url) = try await call("funding") { try await $0.fundingRate(Self.btc) }
        #expect(url == "https://api.mexc.com/api/v1/contract/funding_rate/BTC_USDT")
        #expect(rate.rate == Decimal(string: "0.000033"))
        #expect(rate.maximumRate == Decimal(string: "0.0018"))
        #expect(rate.minimumRate == Decimal(string: "-0.0018"))
        #expect(rate.interval == .seconds(8 * 3600))
        #expect(rate.nextSettlement == Date(timeIntervalSince1970: 1_795_536_000))
        #expect(rate.indexPrice == Decimal(string: "60029.6"))
        #expect(rate.fairPrice == Decimal(string: "60008.5"))
    }

    @Test func `every funding rate`() async throws {
        let (rates, url) = try await call("fundings") { try await $0.fundingRates() }
        #expect(url == "https://api.mexc.com/api/v1/contract/funding_rate/")
        #expect(rates.map(\.symbol) == ["BTC_USDT", "ETH_USDT"])
    }

    @Test func `funding rate history`() async throws {
        let (page, url) = try await call("funding_hist") {
            try await $0.fundingRateHistory(Self.btc, page: .init(number: 1, size: 2))
        }
        #expect(url == "https://api.mexc.com/api/v1/contract/funding_rate/history?page_num=1&page_size=2&symbol=BTC_USDT")
        #expect(page.totalCount == 1620)
        #expect(page.items.first == .init(
            symbol: Self.btc, rate: Decimal(string: "0.000061")!, interval: .seconds(8 * 3600),
            settledAt: Date(timeIntervalSince1970: 1_795_507_200)
        ))
    }

    @Test(arguments: [
        (MexcFutures.CandlePrice.last, "kline", "https://api.mexc.com/api/v1/contract/kline/BTC_USDT"),
        (.index, "kline_index", "https://api.mexc.com/api/v1/contract/kline/index_price/BTC_USDT"),
        (.fair, "kline_fair", "https://api.mexc.com/api/v1/contract/kline/fair_price/BTC_USDT"),
    ])
    func `candles of each price`(price: MexcFutures.CandlePrice, fixture: String, path: String) async throws {
        let (candles, url) = try await call(fixture) {
            try await $0.candles(
                Self.btc, interval: .oneHour, from: Date(timeIntervalSince1970: 1_795_400_000.9),
                to: Date(timeIntervalSince1970: 1_795_410_000), price: price
            )
        }
        #expect(url == path + "?end=1795410000&interval=Min60&start=1795400000")
        #expect(candles.map(\.time) == [1_795_402_800, 1_795_406_400, 1_795_410_000].map { Date(timeIntervalSince1970: $0) })
    }

    @Test func `candles decode exactly`() async throws {
        let (candles, url) = try await call("kline") { try await $0.candles(Self.btc, interval: .oneHour) }
        #expect(url == "https://api.mexc.com/api/v1/contract/kline/BTC_USDT?interval=Min60")
        #expect(candles.first == .init(
            time: Date(timeIntervalSince1970: 1_795_402_800), open: Decimal(string: "60588.1")!,
            high: Decimal(string: "61937.6")!, low: Decimal(string: "60571.4")!, close: Decimal(string: "61264.5")!,
            volume: 29_671_330, turnover: Decimal(string: "182079948.23181")!
        ))
    }

    @Test func `deals come newest first with their sides and effects`() async throws {
        let (deals, url) = try await call("deals") { try await $0.deals(Self.btc, limit: 3) }
        #expect(url == "https://api.mexc.com/api/v1/contract/deals/BTC_USDT?limit=3")
        #expect(deals.first == .init(
            id: "1000000003", price: Decimal(string: "60007.8")!, volume: 8, takerSide: .buy,
            positionEffect: .mixed, isSelfTrade: true, time: Date(timeIntervalSince1970: 1_795_514_791.238)
        ))
        #expect(deals.map(\.takerSide) == [.buy, .sell, .buy])
        #expect(deals.last?.positionEffect == .neitherOpened)
        #expect(deals.last?.isSelfTrade == false)
    }

    @Test func `one ticker`() async throws {
        let (ticker, url) = try await call("ticker") { try await $0.ticker(Self.btc) }
        #expect(url == "https://api.mexc.com/api/v1/contract/ticker?symbol=BTC_USDT")
        #expect(ticker == .init(
            symbol: Self.btc, lastPrice: Decimal(string: "60007.7")!, bestBid: Decimal(string: "60007.7")!,
            bestAsk: Decimal(string: "60007.8")!, indexPrice: Decimal(string: "60029.7")!,
            fairPrice: Decimal(string: "60008.6")!, fundingRate: Decimal(string: "0.000033")!,
            openInterest: 481_053_096, high24h: Decimal(string: "64560.9")!, low24h: 59428, volume24h: 608_890_948,
            turnover24h: Decimal(string: "3748396049.03803")!, dayChange: Decimal(string: "-2859.5")!,
            dayChangeRate: Decimal(string: "-0.0454")!, maximumBidPrice: Decimal(string: "66032.6")!,
            minimumAskPrice: Decimal(string: "54026.7")!, time: Date(timeIntervalSince1970: 1_795_514_789.85)
        ))
    }

    @Test func `every ticker, including one without a bid or an ask`() async throws {
        let (tickers, url) = try await call("tickers") { try await $0.tickers() }
        #expect(url == "https://api.mexc.com/api/v1/contract/ticker")
        #expect(tickers.map(\.symbol) == ["BTC_USDT", "USDGO_USDT"])
        #expect(tickers[0].bestBid != nil && tickers[0].bestAsk != nil)
        #expect(tickers[1].bestBid == nil && tickers[1].bestAsk == nil)
    }

    @Test func `candle columns of different lengths throw DecodingError`() async throws {
        let json = #"""
            {"success":true,"code":0,"data":{"time":[1795402800,1795406400],"open":[1],"close":[1,2],"high":[1,2],
            "low":[1,2],"vol":[1,2],"amount":[1,2]}}
            """#
        let market = MarketEndpoints(rest: .test(transport: FakeTransport(json: json)))
        await #expect(throws: DecodingError.self) { try await market.candles(Self.btc, interval: .oneHour) }
    }

    @Test func `insurance fund keeps every digit`() async throws {
        let (fund, url) = try await call("risk") { try await $0.insuranceFund(Self.btc) }
        #expect(url == "https://api.mexc.com/api/v1/contract/risk_reverse/BTC_USDT")
        #expect(fund.asset == "USDT")
        #expect(fund.balance == Decimal(string: "119935132.119733946013321927359423303647"))
        #expect(fund.time == Date(timeIntervalSince1970: 1_795_514_793.437))
    }

    @Test func `insurance fund history`() async throws {
        let (page, url) = try await call("risk_hist") { try await $0.insuranceFundHistory(Self.btc) }
        #expect(url == "https://api.mexc.com/api/v1/contract/risk_reverse/history?page_num=1&page_size=20&symbol=BTC_USDT")
        #expect(page.items.map(\.time) == [1_795_507_200, 1_795_492_800].map { Date(timeIntervalSince1970: $0) })
    }

    /// Calls the market endpoint with a transport that answers with the fixture, and returns the
    /// result with the URL requested.
    private func call<Value>(
        _ fixture: String, _ body: (MarketEndpoints) async throws -> Value
    ) async throws -> (Value, String) {
        let transport = try FakeTransport(fixture: "Market/\(fixture)")
        let result = try await body(MarketEndpoints(rest: .test(transport: transport)))
        let requests = await transport.requests
        #expect(requests.allSatisfy { $0.method == .get && !$0.headers.contains { $0.name == "ApiKey" } })
        return (result, requests.first?.url.absoluteString ?? "")
    }
}
