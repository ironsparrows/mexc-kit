import Foundation
import MexcKitCore
import Testing

extension MexcKitCoreTests {
    @Suite("Contract")
    struct ContractTests {
        private static let contract = MexcFutures.Contract(
            symbol: "BTC_USDT", displayName: "BTC_USDT PERPETUAL", baseAsset: "BTC", quoteAsset: "USDT",
            settlementAsset: "USDT", contractSize: Decimal(string: "0.0001")!, leverage: 1...500,
            priceTick: Decimal(string: "0.5")!, volumeStep: 10, priceScale: 1, volumeScale: 0, minimumVolume: 10,
            maximumVolume: 400_000, maximumLimitOrderVolume: 2_500_000, takerFeeRate: 0, makerFeeRate: 0,
            initialMarginRate: 0, maintenanceMarginRate: 0, riskLimits: [], marginModes: [.isolated, .cross],
            state: .enabled, allowsAPITrading: true, indexSources: [], depthSteps: [], listedAt: Date(timeIntervalSince1970: 0)
        )

        @Test(arguments: [
            ("60000.3", FloatingPointRoundingRule.down, "60000"),
            ("60000.3", .up, "60000.5"),
            ("60000.3", .toNearestOrEven, "60000.5"),
            ("60000.25", .toNearestOrEven, "60000"),
            ("60000.25", .toNearestOrAwayFromZero, "60000.5"),
            ("60000.3", .towardZero, "60000"),
            ("60000.3", .awayFromZero, "60000.5"),
            ("-1.3", .towardZero, "-1"),
            ("-1.3", .down, "-1.5"),
            ("60000.5", .down, "60000.5"),
        ])
        func `prices snap to the tick`(price: String, rule: FloatingPointRoundingRule, expected: String) {
            #expect(Self.contract.round(price: Decimal(string: price)!, rule: rule) == Decimal(string: expected))
        }

        @Test func `volumes snap to the step`() {
            #expect(Self.contract.round(volume: 1234, rule: .down) == 1230)
            #expect(Self.contract.round(volume: 1234, rule: .up) == 1240)
        }

        @Test func `a float literal rounds to an exact tick`() {
            // 0.000018 as a literal is 0.000018000000000000004096; snapping removes the excess.
            let tiny = MexcFutures.Contract(
                symbol: "X_USDT", displayName: "", baseAsset: "X", quoteAsset: "USDT", settlementAsset: "USDT",
                contractSize: 1, leverage: 1...1, priceTick: Decimal(string: "0.000001")!, volumeStep: 1, priceScale: 6,
                volumeScale: 0, minimumVolume: 1, maximumVolume: 1, maximumLimitOrderVolume: 1, takerFeeRate: 0,
                makerFeeRate: 0, initialMarginRate: 0, maintenanceMarginRate: 0, riskLimits: [], marginModes: [],
                state: .enabled, allowsAPITrading: true, indexSources: [], depthSteps: [], listedAt: .distantPast
            )
            #expect(tiny.round(price: 0.000018, rule: .toNearestOrEven) == Decimal(string: "0.000018"))
        }

        @Test(arguments: [(1, [MexcFutures.MarginMode.isolated]), (2, [.cross]), (3, [.isolated, .cross]), (9, [])] as [(Int, Set<MexcFutures.MarginMode>)])
        func `the opening type gives the margin modes`(openType: Int, modes: Set<MexcFutures.MarginMode>) throws {
            let json = """
                {"symbol":"BTC_USDT","displayNameEn":"BTC","baseCoin":"BTC","quoteCoin":"USDT","settleCoin":"USDT",
                 "contractSize":0.0001,"minLeverage":1,"maxLeverage":5,"priceUnit":0.1,"volUnit":1,"priceScale":1,
                 "volScale":0,"minVol":1,"maxVol":10,"limitMaxVol":10,"takerFeeRate":0,"makerFeeRate":0,
                 "initialMarginRate":0.002,"maintenanceMarginRate":0.001,"positionOpenType":\(openType),"state":7,
                 "apiAllowed":false,"createTime":0}
                """
            let contract = try JSONDecoder().decode(MexcFutures.Contract.self, from: Data(json.utf8))
            #expect(contract.marginModes == modes)
            #expect(contract.state.rawValue == 7)
            #expect(contract.riskLimits.isEmpty && contract.indexSources.isEmpty && contract.depthSteps.isEmpty)
        }

        @Test func `a maximum leverage below the minimum throws instead of trapping`() {
            let json = """
                {"symbol":"BTC_USDT","displayNameEn":"BTC","baseCoin":"BTC","quoteCoin":"USDT","settleCoin":"USDT",
                 "contractSize":0.0001,"minLeverage":5,"maxLeverage":0,"priceUnit":0.1,"volUnit":1,"priceScale":1,
                 "volScale":0,"minVol":1,"maxVol":10,"limitMaxVol":10,"takerFeeRate":0,"makerFeeRate":0,
                 "initialMarginRate":0.002,"maintenanceMarginRate":0.001,"positionOpenType":3,"state":0,
                 "apiAllowed":true,"createTime":0}
                """
            #expect(throws: DecodingError.self) {
                try JSONDecoder().decode(MexcFutures.Contract.self, from: Data(json.utf8))
            }
        }
    }
}
