import Foundation
import MexcKitProtobuf
import SwiftProtobuf
import Testing
@testable import MexcKit

/// Each push of the conditional-order, risk and notice channels mapped to its model, over a fake
/// server.
///
/// No private push has been recorded yet, so the pushes here are built from the examples on MEXC's
/// WebSocket documentation pages (plan orders, TP/SL plan orders, TP/SL prices, trailing orders, risk
/// limit, liquidation risk change, user notifications, chase order failure, position mode change,
/// leverage mode change, trial bonus notification) with the `.proto` messages.
@Suite("Account stream pushes", .timeLimit(.minutes(1)))
struct AccountStreamPushTests {
    private let server: FakeWebSocketServer
    private let streams: StreamEndpoints

    init() {
        server = FakeWebSocketServer()
        streams = .test(server, account: AccountStreamSupport.account)
    }

    // MARK: Conditional orders

    @Test func `a plan order push decodes into a plan order`() async throws {
        let plan = try await first(of: streams.planOrders(), push: .contractPlanOrder(Self.plan), on: "plan.order")
        #expect(plan.id.rawValue == "987654321")
        #expect(plan.symbol == "BTC_USDT")
        #expect(plan.side == .openLong)
        #expect(plan.type == .limit)
        #expect(plan.marginMode == .isolated)
        #expect(plan.leverage == 20)
        #expect(plan.trigger == MexcFutures.Trigger(price: 46000, condition: .atOrAbove, source: .last))
        #expect(plan.price == 45990)
        #expect(plan.volume == 5)
        #expect(plan.state == .untriggered)
        #expect(plan.lifetime == .seconds(24 * 3600))
        #expect(plan.takeProfit == MexcFutures.AttachedStop(price: 47000, source: .last))
        #expect(plan.stopLoss == MexcFutures.AttachedStop(price: 44000, source: .last))
        #expect(plan.order == nil && plan.errorCode == nil && plan.triggerProtection == nil)
        #expect(plan.positionMode == .hedge)
        #expect(plan.reduceOnly == false)
        #expect(plan.createdAt == Date(timeIntervalSince1970: 1_760_942_212))
        #expect(plan.updatedAt == Date(timeIntervalSince1970: 1_760_942_212))
    }

    @Test func `a plan order's placed order, error and position mode are read when set`() async throws {
        var plan = Self.plan
        plan.orderID = "123456789"
        plan.errorCode = 2005
        plan.positionMode = 0
        plan.takeProfitPrice = "0"
        let decoded = try await first(of: streams.planOrders(), push: .contractPlanOrder(plan), on: "plan.order")
        #expect(decoded.order?.rawValue == "123456789")
        #expect(decoded.errorCode == MexcError.Code(rawValue: 2005))
        #expect(decoded.positionMode == nil)
        #expect(decoded.takeProfit == nil)
    }

    @Test(arguments: ["executeCycle", "triggerPrice", "createTime"])
    func `a plan order push without a required value ends the stream with DecodingError`(missing: String) async throws {
        var plan = Self.plan
        switch missing {
        case "executeCycle": plan.clearExecuteCycle()
        case "triggerPrice": plan.clearTriggerPrice()
        default: plan.createTime = 0
        }
        let plans = Task { [streams] in try await AccountStreamSupport.take(1, from: streams.planOrders()) }
        try await logIn()
        await server.send(.binary(try AccountStreamSupport.push("push.personal.plan.order", .contractPlanOrder(plan))))

        await #expect(throws: DecodingError.self) { try await plans.value }
    }

    @Test func `a stop order push decodes into a stop order with a limit stop-loss`() async throws {
        let stop = try await first(of: streams.stopOrders(), push: .contractStopPlanOrder(Self.stop), on: "stop.planorder")
        #expect(stop.id.rawValue == "987654321")
        #expect(stop.symbol == "BTC_USDT")
        #expect(stop.position?.rawValue == "456789123")
        #expect(stop.side == .long)
        #expect(stop.order?.rawValue == "123456789")
        #expect(stop.takeProfit == MexcFutures.StopOrder.Exit(price: 48000, source: .fair))
        #expect(stop.stopLoss == MexcFutures.StopOrder.Exit(price: 42000, source: .last, limitPrice: 41990))
        #expect(stop.volume == 10)
        #expect(stop.state == .untriggered)
        #expect(stop.isFinished == false)
        #expect(stop.triggered == .takeProfit)
        #expect(stop.placedVolume == 10)
        #expect(stop.placedOrder?.rawValue == "987654321")
        #expect(stop.errorCode == nil && stop.triggerProtection == nil)
        #expect(stop.createdAt == Date(timeIntervalSince1970: 1_760_942_212))
        #expect(stop.updatedAt == Date(timeIntervalSince1970: 1_760_942_212))
    }

    @Test func `a stop order's missing IDs, market stop-loss and missing finished flag are read as none`() async throws {
        var stop = Self.stop
        stop.positionID = "0"
        stop.clearPlaceOrderID()
        stop.stopLossType = 0
        stop.triggerSide = 0
        stop.clearIsFinished()
        let decoded = try await first(of: streams.stopOrders(), push: .contractStopPlanOrder(stop), on: "stop.planorder")
        #expect(decoded.position == nil)
        #expect(decoded.placedOrder == nil)
        #expect(decoded.stopLoss?.limitPrice == nil)
        #expect(decoded.triggered == nil)
        #expect(decoded.isFinished == false)
    }

    @Test func `an attached stops push decodes the order's take-profit and stop-loss`() async throws {
        let stops = try await first(of: streams.attachedStops(), push: .contractStopOrder(Self.attachedStops), on: "stop.order")
        #expect(stops == MexcFutures.AttachedStopsUpdate(
            order: MexcFutures.OrderID(rawValue: "123456789"), symbol: "BTC_USDT",
            takeProfit: MexcFutures.AttachedStop(price: 48000, source: .fair),
            stopLoss: MexcFutures.AttachedStop(price: 42000, source: .last)
        ))
    }

    @Test func `a trailing order push decodes into a trailing order`() async throws {
        let trailing = try await first(of: streams.trailingOrders(), push: .contractTrackOrder(Self.trailing), on: "track.order")
        #expect(trailing.id.rawValue == "987654321")
        #expect(trailing.symbol == "BTC_USDT")
        #expect(trailing.side == .openLong)
        #expect(trailing.marginMode == .isolated)
        #expect(trailing.leverage == 20)
        #expect(trailing.volume == 50)
        #expect(trailing.source == .last)
        #expect(trailing.callback == .percentage(Decimal(string: "0.5")!))
        #expect(trailing.activationPrice == 45000)
        #expect(trailing.referencePrice == 44950)
        #expect(trailing.triggerPrice == 44750)
        #expect(trailing.triggerCondition == .atOrBelow)
        #expect(trailing.state == .active)
        #expect(trailing.order?.rawValue == "123456789")
        #expect(trailing.errorCode == nil)
        #expect(trailing.positionMode == .oneWay)
        #expect(trailing.reduceOnly == false)
        #expect(trailing.createdAt == Date(timeIntervalSince1970: 1_760_942_212))
        #expect(trailing.updatedAt == Date(timeIntervalSince1970: 1_760_942_212))
    }

    @Test func `a trailing order not yet active keeps state 0 and has no order`() async throws {
        var trailing = Self.trailing
        trailing.state = 0
        trailing.clearOrderID()
        trailing.clearMarkPrice()
        // A live closing trailing order was pushed without `openType` and `leverage`; `vol` is optional too.
        trailing.clearOpenType()
        trailing.clearLeverage()
        trailing.clearVol()
        let decoded = try await first(of: streams.trailingOrders(), push: .contractTrackOrder(trailing), on: "track.order")
        #expect(decoded.marginMode == nil && decoded.leverage == nil && decoded.volume == nil)
        #expect(decoded.state == .inactive)
        #expect(decoded.order == nil)
        #expect(decoded.referencePrice == nil)
    }

    @Test func `a market stream of a channel without a filter key drops the other markets' pushes`() async throws {
        let bitcoin = Task { [streams] in try await AccountStreamSupport.take(1, from: streams.trailingOrders(["BTC_USDT"])) }
        try await logIn()
        var ether = Self.trailing
        ether.symbol = "ETH_USDT"
        ether.clearCreateTime()
        await server.send(.binary(try AccountStreamSupport.push("push.personal.track.order", .contractTrackOrder(ether))))
        await server.send(.binary(try AccountStreamSupport.push("push.personal.track.order", .contractTrackOrder(Self.trailing))))

        #expect(try await bitcoin.value.map(\.symbol) == ["BTC_USDT"])
    }

    // MARK: Risk

    @Test func `a risk limit push decodes into the position's risk limit tier`() async throws {
        let limit = try await first(of: streams.riskLimits(), push: .contractUserRiskLimit(Self.riskLimit), on: "risk.limit")
        #expect(limit == MexcFutures.PositionRiskLimit(
            symbol: "BTC_USDT", side: .long, marginMode: .isolated,
            limit: MexcFutures.Contract.RiskLimit(
                level: 2, maximumVolume: 500, maintenanceMarginRate: Decimal(string: "0.02")!,
                initialMarginRate: Decimal(string: "0.04")!, maximumLeverage: 50
            )
        ))
    }

    @Test func `a liquidation risk push decodes the position's liquidation price and margin ratio`() async throws {
        let risk = try await first(of: streams.liquidationRisks(), push: .liquidateRiskChange(Self.liquidationRisk), on: "liquidate.risk")
        #expect(risk == MexcFutures.LiquidationRisk(
            symbol: "BTC_USDT", position: MexcFutures.PositionID(rawValue: "123456789"), liquidationPrice: 35000,
            marginRatio: Decimal(string: "0.1")!, autoDeleveragingLevel: 3
        ))
    }

    @Test func `a liquidation notice push decodes, and other notice types are skipped`() async throws {
        let notices = Task { [streams] in try await AccountStreamSupport.take(1, from: streams.liquidationNotices()) }
        try await logIn()
        var other = Self.liquidationNotice
        other.type = 7
        other.param.notifyType = 0
        await server.send(.binary(try AccountStreamSupport.push("push.personal.generic.notify", .notifyGeneric(other))))
        await server.send(.binary(try AccountStreamSupport.push("push.personal.generic.notify", .notifyGeneric(Self.liquidationNotice))))

        #expect(try await notices.value == [MexcFutures.LiquidationNotice(
            kind: .warning, marginMode: .isolated, marketName: "BTC_USDT PERPETUAL", isMultiAssetMode: false,
            marginRatio: Decimal(string: "0.085")!
        )])
    }

    @Test func `a liquidation risk of ADL level 0 has no level`() async throws {
        var risk = Self.liquidationRisk
        risk.adlLevel = 0
        let decoded = try await first(of: streams.liquidationRisks(), push: .liquidateRiskChange(risk), on: "liquidate.risk")
        #expect(decoded.autoDeleveragingLevel == nil)
    }

    // MARK: Notices

    @Test func `a chase failure push decodes its market and error`() async throws {
        let failure = try await first(of: streams.chaseFailures(), push: .orderChase(Self.chaseFailure), on: "order.chase")
        #expect(failure.symbol == "BTC_USDT")
        // MEXC doesn't say which table the code is from; the example's number is kept as sent.
        #expect(failure.errorCode.rawValue == 1001)
    }

    @Test func `a position mode push decodes the new mode`() async throws {
        let mode = try await first(
            of: streams.positionModes(), push: .positionModeResult(.with { $0.positionMode = 2 }), on: "position.mode"
        )
        #expect(mode == .oneWay)
    }

    @Test func `a leverage mode push of -1, no mode, is skipped`() async throws {
        let modes = Task { [streams] in try await AccountStreamSupport.take(1, from: streams.leverageModes()) }
        try await logIn()
        await server.send(.binary(try AccountStreamSupport.push("push.personal.leverage.mode", .leverageMode(.with { $0.lm = -1 }))))
        await server.send(.binary(try AccountStreamSupport.push("push.personal.leverage.mode", .leverageMode(.with { $0.lm = 2 }))))
        #expect(try await modes.value == [.simple])
    }

    @Test func `a leverage mode push decodes the new mode`() async throws {
        let mode = try await first(of: streams.leverageModes(), push: .leverageMode(.with { $0.lm = 1 }), on: "leverage.mode")
        #expect(mode == .advanced)
    }

    @Test func `a trial bonus push decodes the bonus and its expiries`() async throws {
        let bonus = try await first(of: streams.trialBonuses(), push: .bonusNotify(Self.trialBonus), on: "bonus")
        #expect(bonus == MexcFutures.TrialBonusUpdate(
            asset: "USDT", amount: 100, expiresAt: Date(timeIntervalSince1970: 1_763_539_200), isGranted: true,
            nearestExpiry: Date(timeIntervalSince1970: 1_763_539_200), nearestExpiringAmount: 100
        ))
    }

    // MARK: Missing values

    enum MissingValue: CaseIterable {
        case stopOrderSide, trailingOrderCreateTime, riskLimitLevel, liquidationRiskSymbol, noticeParameters
        case chaseErrorCode, bonusAsset, leverageMode, attachedStopsOrder
    }

    @Test(arguments: MissingValue.allCases)
    func `a push without a required value ends its stream with DecodingError`(missing: MissingValue) async throws {
        switch missing {
        case .stopOrderSide:
            var stop = Self.stop
            stop.positionType = 0
            try await expectDecodingError(streams.stopOrders(), push: .contractStopPlanOrder(stop), on: "stop.planorder")
        case .trailingOrderCreateTime:
            var trailing = Self.trailing
            trailing.clearCreateTime()
            try await expectDecodingError(streams.trailingOrders(), push: .contractTrackOrder(trailing), on: "track.order")
        case .riskLimitLevel:
            var limit = Self.riskLimit
            limit.clearLevel()
            try await expectDecodingError(streams.riskLimits(), push: .contractUserRiskLimit(limit), on: "risk.limit")
        case .liquidationRiskSymbol:
            var risk = Self.liquidationRisk
            risk.symbol = ""
            try await expectDecodingError(streams.liquidationRisks(), push: .liquidateRiskChange(risk), on: "liquidate.risk")
        case .noticeParameters:
            var notice = Self.liquidationNotice
            notice.clearParam()
            try await expectDecodingError(streams.liquidationNotices(), push: .notifyGeneric(notice), on: "generic.notify")
        case .chaseErrorCode:
            var failure = Self.chaseFailure
            failure.ec = 0
            try await expectDecodingError(streams.chaseFailures(), push: .orderChase(failure), on: "order.chase")
        case .bonusAsset:
            var bonus = Self.trialBonus
            bonus.clearC()
            try await expectDecodingError(streams.trialBonuses(), push: .bonusNotify(bonus), on: "bonus")
        case .leverageMode:
            try await expectDecodingError(streams.leverageModes(), push: .leverageMode(MexcKitProtobuf.LeverageMode()), on: "leverage.mode")
        case .attachedStopsOrder:
            var stops = Self.attachedStops
            stops.orderID = ""
            try await expectDecodingError(streams.attachedStops(), push: .contractStopOrder(stops), on: "stop.order")
        }
    }

    // MARK: Helpers

    /// Logs in, sends `push` on `push.personal.<channel>` and expects the stream to end with
    /// `DecodingError`.
    private func expectDecodingError<Element: Sendable>(
        _ stream: AsyncThrowingStream<Element, any Error>, push data: ContractWrapper.OneOf_Data, on channel: String
    ) async throws {
        let values = Task { try await AccountStreamSupport.take(1, from: stream) }
        try await logIn()
        await server.send(.binary(try AccountStreamSupport.push("push.personal.\(channel)", data)))
        await #expect(throws: DecodingError.self) { try await values.value }
    }

    /// Answers the login and takes the filter.
    private func logIn() async throws {
        #expect(await server.nextSent() == AccountStreamSupport.login)
        await server.send(#"{"channel":"rs.login","data":"success","ts":1}"#)
        _ = await server.nextSent()
    }

    /// Logs in, sends `push` on `push.personal.<channel>` and returns the stream's first value.
    private func first<Element: Sendable>(
        of stream: AsyncThrowingStream<Element, any Error>, push data: ContractWrapper.OneOf_Data, on channel: String
    ) async throws -> Element {
        try await logIn()
        await server.send(.binary(try AccountStreamSupport.push("push.personal.\(channel)", data)))
        var values = stream.makeAsyncIterator()
        let value = try await values.next()
        return try #require(value)
    }

    // The examples on MEXC's documentation pages, as Protobuf messages.

    private static let plan = ContractPlanOrder.with {
        $0.id = "987654321"
        $0.symbol = "BTC_USDT"
        $0.leverage = 20
        $0.side = 1
        $0.triggerPrice = "46000.0"
        $0.price = "45990.0"
        $0.vol = "5"
        $0.openType = 1
        $0.triggerType = 1
        $0.state = 1
        $0.executeCycle = 24
        $0.trend = 1
        $0.errorCode = 0
        $0.orderID = "0"
        $0.orderType = 1
        $0.marketOrderLevel = 0
        $0.positionMode = 1
        $0.lossTrend = 1
        $0.profitTrend = 1
        $0.stopLossPrice = "44000.0"
        $0.takeProfitPrice = "47000.0"
        $0.reduceOnly = false
        $0.createTime = 1_760_942_212_000
        $0.updateTime = 1_760_942_212_000
    }

    private static let stop = ContractStopPlanOrder.with {
        $0.id = 987_654_321
        $0.orderID = "123456789"
        $0.symbol = "BTC_USDT"
        $0.positionID = "456789123"
        $0.lossTrend = 1
        $0.profitTrend = 2
        $0.stopLossPrice = "42000.0"
        $0.takeProfitPrice = "48000.0"
        $0.state = 1
        $0.triggerSide = 1
        $0.positionType = 1
        $0.vol = "10"
        $0.takeProfitVol = "10"
        $0.stopLossVol = "10"
        $0.realityVol = "10"
        $0.placeOrderID = "987654321"
        $0.version = 1
        $0.isFinished = 0
        $0.profitLossVolType = "SAME"
        $0.volType = 1
        $0.takeProfitReverse = 2
        $0.stopLossReverse = 2
        $0.closeTryTimes = 0
        $0.reverseTryTimes = 0
        $0.reverseErrorCode = 0
        $0.stopLossType = 1
        $0.stopLossOrderPrice = "41990.0"
        $0.createTime = 1_760_942_212_000
        $0.updateTime = 1_760_942_212_000
    }

    private static let attachedStops = ContractStopOrder.with {
        $0.symbol = "BTC_USDT"
        $0.orderID = "123456789"
        $0.lossTrend = 1
        $0.profitTrend = 2
        $0.stopLossPrice = "42000.0"
        $0.takeProfitPrice = "48000.0"
    }

    private static let trailing = ContractTrackOrder.with {
        $0.id = "987654321"
        $0.symbol = "BTC_USDT"
        $0.leverage = 20
        $0.side = 1
        $0.vol = "50"
        $0.openType = 1
        $0.trend = 1
        $0.activePrice = "45000.0"
        $0.markPrice = "44950.0"
        $0.backType = 1
        $0.backValue = "0.5"
        $0.triggerPrice = "44750.0"
        $0.triggerType = 2
        $0.orderID = 123_456_789
        $0.errorCode = 0
        $0.state = 1
        $0.positionMode = 2
        $0.reduceOnly = false
        $0.createTime = 1_760_942_212_000
        $0.updateTime = 1_760_942_212_000
    }

    private static let riskLimit = ContractUserRiskLimit.with {
        $0.symbol = "BTC_USDT"
        $0.positionType = 1
        $0.riskSource = 1
        $0.level = 2
        $0.maxVol = "500"
        $0.maxLeverage = 50
        $0.mmr = "0.02"
        $0.imr = "0.04"
        $0.leverage = 20
        $0.openType = 1
        $0.limitBySys = true
        $0.maxVolView = "1000"
    }

    private static let liquidationRisk = LiquidateRiskChange.with {
        $0.symbol = "BTC_USDT"
        $0.positionID = 123_456_789
        $0.liquidatePrice = "35000.0"
        $0.marginRatio = "0.1"
        $0.adlLevel = 3
    }

    private static let liquidationNotice = NotifyGeneric.with {
        $0.type = 1
        $0.param = .with {
            $0.notifyType = 2
            $0.openType = 1
            $0.dn = "BTC_USDT永续"
            $0.dne = "BTC_USDT PERPETUAL"
            $0.multiAssets = false
            $0.marginRate = "0.085"
        }
    }

    private static let chaseFailure = OrderChase.with {
        $0.ec = 1001
        $0.s = "BTC_USDT"
    }

    private static let trialBonus = BonusNotify.with {
        $0.c = "USDT"
        $0.b = "100.0"
        $0.be = 1_763_539_200_000
        $0.g = true
        $0.ret = 1_763_539_200_000
        $0.rea = "100.0"
    }
}
