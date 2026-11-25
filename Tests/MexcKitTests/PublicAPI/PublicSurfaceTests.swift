import MexcKit
import Testing

// Only `import MexcKit`: the check is that this compiles. It stops compiling if a public type stops
// reaching apps through the umbrella module.
extension MexcKitTests {
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
                (any MexcFutures.StreamAPI).self, MexcFutures.TickerSummary.self, MexcFutures.BalanceUpdate.self,
                MexcFutures.AttachedStopsUpdate.self, MexcFutures.LiquidationRisk.self, MexcFutures.LiquidationNotice.self,
                MexcFutures.LiquidationNotice.Kind.self, MexcFutures.ChaseFailure.self, MexcFutures.TrialBonusUpdate.self,
                MexcFutures.LeverageMode.self,
                MexcFutures.Contract.self, MexcFutures.Contract.RiskLimit.self, MexcFutures.Contract.State.self,
                MexcFutures.Ticker.self, MexcFutures.OrderBook.self, MexcFutures.OrderBook.Level.self,
                MexcFutures.OrderBook.Change.self, MexcFutures.OrderBookSync.self, MexcFutures.Candle.self, MexcFutures.Candle.Interval.self,
                MexcFutures.Deal.self, MexcFutures.Deal.TakerSide.self, MexcFutures.Deal.PositionEffect.self,
                MexcFutures.FundingRate.self, MexcFutures.FundingRate.Settlement.self, MexcFutures.InsuranceFund.self,
                MexcFutures.PriceSnapshot.self,
                (any MexcFutures.AccountAPI).self, (any MexcFutures.PositionAPI).self, MexcFutures.Balance.self,
                MexcFutures.Transfer.self, MexcFutures.TransferDirection.self, MexcFutures.ProfitRate.self,
                MexcFutures.PositionRiskLimit.self, MexcFutures.Position.self, MexcFutures.PositionState.self,
                MexcFutures.FundingPayment.self, MexcFutures.LeverageSetting.self,
                (any MexcFutures.OrderAPI).self, MexcFutures.OrderRequest.self, MexcFutures.OrderRequest.Pricing.self, MexcFutures.OrderRequest.Direction.self,
                MexcFutures.OrderRequest.Options.self, MexcFutures.AttachedStop.self, MexcFutures.Order.self,
                MexcFutures.Fill.self, MexcFutures.FillID.self, MexcFutures.PlacedOrder.self,
                MexcFutures.PendingOrderCounts.self, MexcFutures.BatchResult<MexcFutures.OrderID>.self,
                MexcFutures.FeeRates.self, MexcFutures.FeeRates.Mode.self, MexcFutures.FeeRates.Tier.self,
                MexcFutures.FeeTotals.self, MexcFutures.DiscountUsage.self, MexcFutures.FeeDeductionAsset.self,
                MexcFutures.FeeDiscount.self, MexcFutures.FeeDiscount.Level.self, MexcFutures.FeeDeduction.self,
                MexcFutures.FeeDeduction.Source.self,
                (any MexcFutures.PlanOrderAPI).self, (any MexcFutures.StopOrderAPI).self,
                (any MexcFutures.TrailingOrderAPI).self, MexcFutures.Trigger.self, MexcFutures.PlanOrderRequest.self,
                MexcFutures.PlanOrderRequest.Lifetime.self, MexcFutures.PlanOrderRequest.Options.self,
                MexcFutures.PlanOrder.self, MexcFutures.StopOrderRequest.self, MexcFutures.StopOrder.self,
                MexcFutures.StopOrder.Exit.self, MexcFutures.StopOrder.Leg.self, MexcFutures.TrailingOrderRequest.self,
                MexcFutures.TrailingOrder.self, MexcFutures.TrailingOrder.Callback.self,
                MexcFutures.TrailingOrder.Callback.Kind.self,
                (any MexcFutures.SelfTradePreventionAPI).self, MexcFutures.SelfTradePreventionGroup.self,
            ]
            _ = types
        }
    }
}
