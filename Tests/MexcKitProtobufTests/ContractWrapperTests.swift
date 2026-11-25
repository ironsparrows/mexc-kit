import Foundation
import MexcKitProtobuf
import MexcKitTestSupport
import SwiftProtobuf
import Testing

extension MexcKitProtobufTests {
    /// Decodes binary push frames recorded from `wss://contract.mexc.com/edge?Trans-Protocol=Protobuf`,
    /// byte for byte as MEXC sent them.
    ///
    /// Every public channel has a frame except `push.funding.rate` and `push.contract`, which push only
    /// when a value changes and sent nothing while recording.
    @Suite("Contract wrapper")
    struct ContractWrapperTests {
        @Test(arguments: [
            ("push.deal.BTC_USDT", "push.deal", "BTC_USDT"),
            ("push.deal.ETH_USDT", "push.deal", "ETH_USDT"),
            ("push.depth.BTC_USDT", "push.depth", "BTC_USDT"),
            ("push.depth.full.SOL_USDT", "push.depth.full", "SOL_USDT"),
            ("push.depth.step.DOGE_USDT", "push.depth.step", "DOGE_USDT"),
            ("push.fair.price.BTC_USDT", "push.fair.price", "BTC_USDT"),
            ("push.index.price.BTC_USDT", "push.index.price", "BTC_USDT"),
            ("push.kline.BTC_USDT", "push.kline", "BTC_USDT"),
            ("push.ticker.BTC_USDT", "push.ticker", "BTC_USDT"),
            ("push.tickers", "push.tickers", ""),
        ])
        func `every recorded frame decodes with its channel, symbol and data`(
            fixture: String, channel: String, symbol: String
        ) throws {
            let wrapper = try frame(fixture)
            #expect(wrapper.channel == channel)
            #expect(wrapper.symbol == symbol)
            #expect(wrapper.data != nil)
            #expect(wrapper.unknownFields.data.isEmpty)
        }

        @Test func `a merged deal has no trade ID`() throws {
            let wrapper = try frame("push.deal.BTC_USDT")
            guard case .deal(let deal) = wrapper.data else {
                Issue.record("Expected a deal, got \(String(describing: wrapper.data))")
                return
            }
            #expect(wrapper.symbol == "BTC_USDT")
            #expect(wrapper.ts == 1_795_506_146_872)
            #expect(deal.p == "60391.6")
            #expect(deal.v == "792")
            #expect(deal.t == 1)
            #expect(deal.o == 3)
            #expect(deal.m == 2)
            #expect(deal.ts == 1_795_506_146_872)
            #expect(!deal.hasI)
        }

        @Test func `a deal pushed one trade at a time carries its trade ID`() throws {
            let wrapper = try frame("push.deal.ETH_USDT")
            guard case .deal(let deal) = wrapper.data else {
                Issue.record("Expected a deal, got \(String(describing: wrapper.data))")
                return
            }
            #expect(deal.p == "1697.71")
            #expect(deal.v == "9")
            #expect(deal.t == 2)
            #expect(deal.i == 17_146_825_672)
        }

        @Test func `a depth change carries its levels and version`() throws {
            guard case .depthInfo(let depth) = try frame("push.depth.BTC_USDT").data else {
                Issue.record("Expected depth")
                return
            }
            #expect(depth.asks.map(\.price) == ["60391.6"])
            #expect(depth.asks.map(\.vol) == ["446741"])
            #expect(depth.asks.map(\.count) == [1])
            #expect(depth.bids.isEmpty)
            #expect(depth.version == 43_829_097_504)
        }

        @Test func `a full depth frame carries the requested number of levels`() throws {
            guard case .depthInfo(let depth) = try frame("push.depth.full.SOL_USDT").data else {
                Issue.record("Expected depth")
                return
            }
            #expect(depth.asks.count == 5)
            #expect(depth.bids.count == 5)
            #expect(depth.asks.first?.price == "71.53")
            #expect(depth.version == 16_028_896_953)
        }

        @Test func `a stepped depth frame carries its market level prices`() throws {
            guard case .depthStepInfo(let depth) = try frame("push.depth.step.DOGE_USDT").data else {
                Issue.record("Expected stepped depth")
                return
            }
            #expect(depth.asks.count == 25)
            #expect(depth.bids.count == 25)
            #expect(depth.asks.first?.price == "0.057")
            #expect(depth.bidMarketLevelPrice == "0.05598")
            #expect(depth.askMarketLevelPrice == "0.05637")
            #expect(depth.version == 9_005_389_635)
        }

        @Test func `a candle carries its interval and start in seconds`() throws {
            guard case .wsKline(let candle) = try frame("push.kline.BTC_USDT").data else {
                Issue.record("Expected a candle")
                return
            }
            #expect(candle.symbol == "BTC_USDT")
            #expect(candle.interval == .min1)
            #expect(candle.t == 1_795_506_120)
            #expect([candle.o, candle.c, candle.h, candle.l] == ["60383.4", "60391.5", "60396.8", "60362.8"])
            #expect(candle.a == "2175623.96616")
            #expect(candle.q == "360276")
        }

        @Test func `an index price carries its symbol and price`() throws {
            guard case .indexPrice(let index) = try frame("push.index.price.BTC_USDT").data else {
                Issue.record("Expected an index price")
                return
            }
            #expect(index.symbol == "BTC_USDT")
            #expect(index.price == "60426.7")
        }

        @Test func `a fair price carries its symbol and price`() throws {
            guard case .fairPrice(let fair) = try frame("push.fair.price.BTC_USDT").data else {
                Issue.record("Expected a fair price")
                return
            }
            #expect(fair.symbol == "BTC_USDT")
            #expect(fair.price == "60395")
        }

        @Test func `a ticker carries prices as decimal strings`() throws {
            guard case .tickerDetail(let ticker) = try frame("push.ticker.BTC_USDT").data else {
                Issue.record("Expected a ticker")
                return
            }
            #expect(ticker.symbol == "BTC_USDT")
            #expect(ticker.lastPrice == "60391.5")
            #expect(ticker.bid1 == "60391.5")
            #expect(ticker.ask1 == "60391.6")
            #expect(ticker.riseFallValue == "-2475.7")
            #expect(ticker.fundingRate == "0.000067")
            #expect(ticker.timestamp == 1_795_506_148_097)
        }

        /// The largest recorded frame: about 129 KB.
        @Test func `the all-market tickers frame carries every market`() throws {
            let wrapper = try frame("push.tickers")
            guard case .tickerList(let list) = wrapper.data else {
                Issue.record("Expected a ticker list")
                return
            }
            #expect(list.ticker.count == 1181)
            let bitcoin = try #require(list.ticker.first { $0.symbol == "BTC_USDT" })
            #expect(bitcoin.lastPrice == "60389.7")
        }

        @Test func `a push type the generated code doesn't know decodes without data`() throws {
            var known = ContractWrapper()
            known.symbol = "BTC_USDT"
            known.channel = "push.new"
            known.ts = 1
            // Field 9999, length-delimited, holding a message with field 1 set to 1.
            let unknownField: [UInt8] = [0xFA, 0xF0, 0x04, 0x02, 0x08, 0x01]
            let bytes: [UInt8] = try known.serializedBytes() + unknownField

            let wrapper = try ContractWrapper(serializedBytes: bytes)

            #expect(wrapper.channel == "push.new")
            #expect(wrapper.data == nil)
            #expect(Array(wrapper.unknownFields.data) == unknownField)
        }

        private func frame(_ name: String) throws -> ContractWrapper {
            try ContractWrapper(serializedBytes: Fixture.push(name))
        }
    }
}
