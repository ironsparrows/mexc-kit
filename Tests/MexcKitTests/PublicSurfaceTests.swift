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
        ]
        _ = types
    }
}
