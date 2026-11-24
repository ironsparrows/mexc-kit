import Foundation
import MexcKitCore
import Testing

@Suite("Vocabulary")
struct VocabularyTests {
    enum Vocabulary: CaseIterable, Sendable {
        case orderType, orderSide, orderState, orderCategory, orderErrorCode, bestPrice
        case selfTradePreventionMode, positionSide, marginMode, positionMode, priceSource
        case triggerCondition, planOrderState, trailingOrderState, profitRatePeriod
        case contractState, dealTakerSide, dealPositionEffect, positionState
    }

    @Test(arguments: Vocabulary.allCases)
    func `a value MEXC adds later decodes and encodes back unchanged`(vocabulary: Vocabulary) throws {
        let json = "[77]"
        #expect(try roundTrip(vocabulary, json) == json)
    }

    @Test func `an unknown transfer state decodes and encodes back unchanged`() throws {
        let json = #"["PROCESSING"]"#
        let decoded = try JSONDecoder().decode([MexcFutures.TransferState].self, from: Data(json.utf8))
        #expect(decoded.first?.rawValue == "PROCESSING")
        #expect(String(decoding: try JSONEncoder().encode(decoded), as: UTF8.self) == json)
    }

    @Test func `an unknown transfer direction decodes and encodes back unchanged`() throws {
        let json = #"["SIDEWAYS"]"#
        #expect(try roundTrip(MexcFutures.TransferDirection.self, json) == json)
    }

    @Test func `an unknown candle interval decodes and encodes back unchanged`() throws {
        let json = #"["Min3"]"#
        #expect(try roundTrip(MexcFutures.Candle.Interval.self, json) == json)
    }

    // Values from MEXC's documentation, so a mistyped raw value fails here.
    @Test(arguments: [
        ("OrderType.limit", MexcFutures.OrderType.limit.rawValue, 1),
        ("OrderType.postOnly", MexcFutures.OrderType.postOnly.rawValue, 2),
        ("OrderType.immediateOrCancel", MexcFutures.OrderType.immediateOrCancel.rawValue, 3),
        ("OrderType.fillOrKill", MexcFutures.OrderType.fillOrKill.rawValue, 4),
        ("OrderType.market", MexcFutures.OrderType.market.rawValue, 5),
        ("OrderType.marketToLimit", MexcFutures.OrderType.marketToLimit.rawValue, 6),
        ("OrderSide.openLong", MexcFutures.OrderSide.openLong.rawValue, 1),
        ("OrderSide.closeShort", MexcFutures.OrderSide.closeShort.rawValue, 2),
        ("OrderSide.openShort", MexcFutures.OrderSide.openShort.rawValue, 3),
        ("OrderSide.closeLong", MexcFutures.OrderSide.closeLong.rawValue, 4),
        ("OrderState.pending", MexcFutures.OrderState.pending.rawValue, 1),
        ("OrderState.open", MexcFutures.OrderState.open.rawValue, 2),
        ("OrderState.filled", MexcFutures.OrderState.filled.rawValue, 3),
        ("OrderState.canceled", MexcFutures.OrderState.canceled.rawValue, 4),
        ("OrderState.invalid", MexcFutures.OrderState.invalid.rawValue, 5),
        ("OrderCategory.limit", MexcFutures.OrderCategory.limit.rawValue, 1),
        ("OrderCategory.liquidationCustody", MexcFutures.OrderCategory.liquidationCustody.rawValue, 2),
        ("OrderCategory.custodyClose", MexcFutures.OrderCategory.custodyClose.rawValue, 3),
        ("OrderCategory.autoDeleveraging", MexcFutures.OrderCategory.autoDeleveraging.rawValue, 4),
        ("OrderCategory.delivery", MexcFutures.OrderCategory.delivery.rawValue, 5),
        ("OrderCategory.liquidationHedge", MexcFutures.OrderCategory.liquidationHedge.rawValue, 6),
        ("OrderErrorCode.normal", MexcFutures.OrderErrorCode.normal.rawValue, 0),
        ("OrderErrorCode.invalidParameter", MexcFutures.OrderErrorCode.invalidParameter.rawValue, 1),
        ("OrderErrorCode.insufficientBalance", MexcFutures.OrderErrorCode.insufficientBalance.rawValue, 2),
        ("OrderErrorCode.positionNotFound", MexcFutures.OrderErrorCode.positionNotFound.rawValue, 3),
        ("OrderErrorCode.insufficientPosition", MexcFutures.OrderErrorCode.insufficientPosition.rawValue, 4),
        ("OrderErrorCode.positionLiquidated", MexcFutures.OrderErrorCode.positionLiquidated.rawValue, 5),
        ("OrderErrorCode.orderLiquidated", MexcFutures.OrderErrorCode.orderLiquidated.rawValue, 6),
        ("OrderErrorCode.riskLevelLimit", MexcFutures.OrderErrorCode.riskLevelLimit.rawValue, 7),
        ("OrderErrorCode.canceledBySystem", MexcFutures.OrderErrorCode.canceledBySystem.rawValue, 8),
        ("OrderErrorCode.positionModeMismatch", MexcFutures.OrderErrorCode.positionModeMismatch.rawValue, 9),
        ("OrderErrorCode.reduceOnlyLiquidated", MexcFutures.OrderErrorCode.reduceOnlyLiquidated.rawValue, 10),
        ("OrderErrorCode.contractNotEnabled", MexcFutures.OrderErrorCode.contractNotEnabled.rawValue, 11),
        ("OrderErrorCode.canceledForDelivery", MexcFutures.OrderErrorCode.canceledForDelivery.rawValue, 12),
        ("OrderErrorCode.canceledForPositionLiquidation", MexcFutures.OrderErrorCode.canceledForPositionLiquidation.rawValue, 13),
        ("OrderErrorCode.canceledForAutoDeleveraging", MexcFutures.OrderErrorCode.canceledForAutoDeleveraging.rawValue, 14),
        ("OrderErrorCode.canceledForBlacklistedUser", MexcFutures.OrderErrorCode.canceledForBlacklistedUser.rawValue, 15),
        ("OrderErrorCode.canceledForFundingSettlement", MexcFutures.OrderErrorCode.canceledForFundingSettlement.rawValue, 16),
        ("OrderErrorCode.canceledForInitialMarginChange", MexcFutures.OrderErrorCode.canceledForInitialMarginChange.rawValue, 17),
        ("OrderErrorCode.canceledImmediateOrCancel", MexcFutures.OrderErrorCode.canceledImmediateOrCancel.rawValue, 18),
        ("OrderErrorCode.canceledFillOrKill", MexcFutures.OrderErrorCode.canceledFillOrKill.rawValue, 19),
        ("OrderErrorCode.canceledPostOnly", MexcFutures.OrderErrorCode.canceledPostOnly.rawValue, 20),
        ("OrderErrorCode.canceledMarket", MexcFutures.OrderErrorCode.canceledMarket.rawValue, 21),
        ("OrderErrorCode.duplicateOrderID", MexcFutures.OrderErrorCode.duplicateOrderID.rawValue, 22),
        ("OrderErrorCode.duplicateClientOrderID", MexcFutures.OrderErrorCode.duplicateClientOrderID.rawValue, 23),
        ("OrderErrorCode.other", MexcFutures.OrderErrorCode.other.rawValue, 999),
        ("BestPrice.opposite1", MexcFutures.BestPrice.opposite1.rawValue, 1),
        ("BestPrice.opposite5", MexcFutures.BestPrice.opposite5.rawValue, 2),
        ("BestPrice.sameSide1", MexcFutures.BestPrice.sameSide1.rawValue, 3),
        ("BestPrice.sameSide5", MexcFutures.BestPrice.sameSide5.rawValue, 4),
        ("SelfTradePreventionMode.off", MexcFutures.SelfTradePreventionMode.off.rawValue, 0),
        ("SelfTradePreventionMode.cancelBoth", MexcFutures.SelfTradePreventionMode.cancelBoth.rawValue, 1),
        ("SelfTradePreventionMode.cancelMaker", MexcFutures.SelfTradePreventionMode.cancelMaker.rawValue, 2),
        ("SelfTradePreventionMode.cancelTaker", MexcFutures.SelfTradePreventionMode.cancelTaker.rawValue, 3),
        ("PositionSide.long", MexcFutures.PositionSide.long.rawValue, 1),
        ("PositionSide.short", MexcFutures.PositionSide.short.rawValue, 2),
        ("MarginMode.isolated", MexcFutures.MarginMode.isolated.rawValue, 1),
        ("MarginMode.cross", MexcFutures.MarginMode.cross.rawValue, 2),
        ("PositionMode.hedge", MexcFutures.PositionMode.hedge.rawValue, 1),
        ("PositionMode.oneWay", MexcFutures.PositionMode.oneWay.rawValue, 2),
        ("PriceSource.last", MexcFutures.PriceSource.last.rawValue, 1),
        ("PriceSource.fair", MexcFutures.PriceSource.fair.rawValue, 2),
        ("PriceSource.index", MexcFutures.PriceSource.index.rawValue, 3),
        ("TriggerCondition.atOrAbove", MexcFutures.TriggerCondition.atOrAbove.rawValue, 1),
        ("TriggerCondition.atOrBelow", MexcFutures.TriggerCondition.atOrBelow.rawValue, 2),
        ("PlanOrderState.untriggered", MexcFutures.PlanOrderState.untriggered.rawValue, 1),
        ("PlanOrderState.canceled", MexcFutures.PlanOrderState.canceled.rawValue, 2),
        ("PlanOrderState.executed", MexcFutures.PlanOrderState.executed.rawValue, 3),
        ("PlanOrderState.invalid", MexcFutures.PlanOrderState.invalid.rawValue, 4),
        ("PlanOrderState.failed", MexcFutures.PlanOrderState.failed.rawValue, 5),
        ("TrailingOrderState.inactive", MexcFutures.TrailingOrderState.inactive.rawValue, 0),
        ("TrailingOrderState.active", MexcFutures.TrailingOrderState.active.rawValue, 1),
        ("TrailingOrderState.triggered", MexcFutures.TrailingOrderState.triggered.rawValue, 2),
        ("TrailingOrderState.failed", MexcFutures.TrailingOrderState.failed.rawValue, 3),
        ("TrailingOrderState.canceled", MexcFutures.TrailingOrderState.canceled.rawValue, 4),
        ("ProfitRatePeriod.day", MexcFutures.ProfitRatePeriod.day.rawValue, 1),
        ("ProfitRatePeriod.week", MexcFutures.ProfitRatePeriod.week.rawValue, 2),
        ("PositionState.holding", MexcFutures.PositionState.holding.rawValue, 1),
        ("PositionState.systemHeld", MexcFutures.PositionState.systemHeld.rawValue, 2),
        ("PositionState.closed", MexcFutures.PositionState.closed.rawValue, 3),
        ("Contract.State.enabled", MexcFutures.Contract.State.enabled.rawValue, 0),
        ("Contract.State.paused", MexcFutures.Contract.State.paused.rawValue, 4),
        ("Deal.TakerSide.buy", MexcFutures.Deal.TakerSide.buy.rawValue, 1),
        ("Deal.TakerSide.sell", MexcFutures.Deal.TakerSide.sell.rawValue, 2),
        ("Deal.PositionEffect.bothOpened", MexcFutures.Deal.PositionEffect.bothOpened.rawValue, 1),
        ("Deal.PositionEffect.mixed", MexcFutures.Deal.PositionEffect.mixed.rawValue, 3),
    ])
    func `each member has MEXC's documented wire value`(member: String, rawValue: Int, documented: Int) {
        #expect(rawValue == documented, "\(member)")
    }

    @Test(arguments: [
        (MexcFutures.Candle.Interval.oneMinute, "Min1"), (.fiveMinutes, "Min5"), (.fifteenMinutes, "Min15"),
        (.thirtyMinutes, "Min30"), (.oneHour, "Min60"), (.fourHours, "Hour4"), (.eightHours, "Hour8"),
        (.oneDay, "Day1"), (.oneWeek, "Week1"), (.oneMonth, "Month1"),
    ])
    func `each candle interval has MEXC's documented wire value`(interval: MexcFutures.Candle.Interval, documented: String) {
        #expect(interval.rawValue == documented)
    }

    @Test(arguments: [
        (MexcFutures.TransferState.waiting, "WAIT"), (.succeeded, "SUCCESS"), (.failed, "FAILED"),
    ])
    func `each transfer state has MEXC's documented wire value`(state: MexcFutures.TransferState, documented: String) {
        #expect(state.rawValue == documented)
    }

    @Test(arguments: [(MexcFutures.TransferDirection.incoming, "IN"), (.outgoing, "OUT")])
    func `each transfer direction has MEXC's documented wire value`(
        direction: MexcFutures.TransferDirection, documented: String
    ) {
        #expect(direction.rawValue == documented)
    }

    private func roundTrip(_ vocabulary: Vocabulary, _ json: String) throws -> String {
        switch vocabulary {
        case .orderType: try roundTrip(MexcFutures.OrderType.self, json)
        case .orderSide: try roundTrip(MexcFutures.OrderSide.self, json)
        case .orderState: try roundTrip(MexcFutures.OrderState.self, json)
        case .orderCategory: try roundTrip(MexcFutures.OrderCategory.self, json)
        case .orderErrorCode: try roundTrip(MexcFutures.OrderErrorCode.self, json)
        case .bestPrice: try roundTrip(MexcFutures.BestPrice.self, json)
        case .selfTradePreventionMode: try roundTrip(MexcFutures.SelfTradePreventionMode.self, json)
        case .positionSide: try roundTrip(MexcFutures.PositionSide.self, json)
        case .marginMode: try roundTrip(MexcFutures.MarginMode.self, json)
        case .positionMode: try roundTrip(MexcFutures.PositionMode.self, json)
        case .priceSource: try roundTrip(MexcFutures.PriceSource.self, json)
        case .triggerCondition: try roundTrip(MexcFutures.TriggerCondition.self, json)
        case .planOrderState: try roundTrip(MexcFutures.PlanOrderState.self, json)
        case .trailingOrderState: try roundTrip(MexcFutures.TrailingOrderState.self, json)
        case .profitRatePeriod: try roundTrip(MexcFutures.ProfitRatePeriod.self, json)
        case .contractState: try roundTrip(MexcFutures.Contract.State.self, json)
        case .dealTakerSide: try roundTrip(MexcFutures.Deal.TakerSide.self, json)
        case .dealPositionEffect: try roundTrip(MexcFutures.Deal.PositionEffect.self, json)
        case .positionState: try roundTrip(MexcFutures.PositionState.self, json)
        }
    }

    private func roundTrip<Value: Codable>(_ type: Value.Type, _ json: String) throws -> String {
        let decoded = try JSONDecoder().decode([Value].self, from: Data(json.utf8))
        return String(decoding: try JSONEncoder().encode(decoded), as: UTF8.self)
    }
}
