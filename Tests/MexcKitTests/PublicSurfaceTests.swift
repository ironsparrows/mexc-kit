import MexcKit
import Testing

// Only `import MexcKit`: the check is that this compiles. It stops compiling if a public type stops
// reaching apps through the umbrella module.
@Suite("Public surface")
struct PublicSurfaceTests {
    @Test func `every public type is reachable through import MexcKit`() {
        let types: [Any.Type] = [
            MexcFutures.self, MexcError.self, MexcError.Code.self, MexcCredentials.self,
            MexcFutures.ClientError.self, MexcFutures.ClientError.Reason.self,
            MexcFutures.Page<Int>.self, MexcFutures.PageRequest.self,
            MexcFutures.Symbol.self, MexcFutures.OrderID.self, MexcFutures.ExternalOrderID.self,
            MexcFutures.PositionID.self, MexcFutures.PlanOrderID.self, MexcFutures.StopOrderID.self,
            MexcFutures.TrailingOrderID.self,
            MexcFutures.OrderType.self, MexcFutures.OrderSide.self, MexcFutures.OrderState.self,
            MexcFutures.OrderCategory.self, MexcFutures.OrderErrorCode.self, MexcFutures.BestPrice.self,
            MexcFutures.SelfTradePreventionMode.self, MexcFutures.PositionSide.self, MexcFutures.MarginMode.self,
            MexcFutures.PositionMode.self, MexcFutures.PriceSource.self, MexcFutures.TriggerCondition.self,
            MexcFutures.PlanOrderState.self, MexcFutures.TrailingOrderState.self, MexcFutures.TransferState.self,
            MexcFutures.ProfitRatePeriod.self,
            MexcFutures.Client.self, MexcFutures.Client.Configuration.self,
            (any MexcFutures.API).self, (any MexcFutures.MarketAPI).self, MexcFutures.CandlePrice.self,
            MexcFutures.Contract.self, MexcFutures.Contract.RiskLimit.self, MexcFutures.Contract.State.self,
            MexcFutures.Ticker.self, MexcFutures.OrderBook.self, MexcFutures.OrderBook.Level.self,
            MexcFutures.OrderBook.Change.self, MexcFutures.Candle.self, MexcFutures.Candle.Interval.self,
            MexcFutures.Deal.self, MexcFutures.Deal.TakerSide.self, MexcFutures.Deal.PositionEffect.self,
            MexcFutures.FundingRate.self, MexcFutures.FundingRate.Settlement.self, MexcFutures.InsuranceFund.self,
            MexcFutures.PriceSnapshot.self,
        ]
        _ = types
    }
}
