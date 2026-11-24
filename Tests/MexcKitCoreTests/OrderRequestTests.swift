import Foundation
import MexcKitCore
import Testing

@Suite("Order requests")
struct OrderRequestTests {
    @Test(arguments: [
        (MexcFutures.OrderRequest.Direction.long, MexcFutures.OrderSide.openLong, MexcFutures.OrderSide.closeLong),
        (.short, .openShort, .closeShort),
    ])
    func `opening and closing pick MEXC's order side`(
        direction: MexcFutures.OrderRequest.Direction, opening: MexcFutures.OrderSide, closing: MexcFutures.OrderSide
    ) {
        #expect(MexcFutures.OrderRequest.open(direction, "BTC_USDT", .market, volume: 1, leverage: 5, margin: .cross).side == opening)
        #expect(MexcFutures.OrderRequest.close(direction, "BTC_USDT", .market, volume: 1, margin: .cross).side == closing)
    }

    @Test func `opening carries the leverage and stops; closing carries the position`() {
        let open = MexcFutures.OrderRequest.open(
            .long, "BTC_USDT", .limit(price: 100), volume: 2, leverage: 20, margin: .isolated,
            takeProfit: .init(price: 120), stopLoss: .init(price: 90, trigger: .fair)
        )
        #expect(open.leverage == 20)
        #expect(open.takeProfit == .init(price: 120, trigger: .last))
        #expect(open.stopLoss?.trigger == .fair)
        #expect(open.position == nil)

        let close = MexcFutures.OrderRequest.close(
            .long, "BTC_USDT", .market, volume: 2, margin: .isolated, position: .init(rawValue: "9")
        )
        #expect(close.leverage == nil)
        #expect(close.takeProfit == nil && close.stopLoss == nil)
        #expect(close.position == .init(rawValue: "9"))
    }

    @Test(arguments: [
        (MexcFutures.OrderRequest.Pricing.limit(price: 1), MexcFutures.OrderType.limit, Decimal?(1), MexcFutures.BestPrice?.none),
        (.postOnly(price: 2), .postOnly, 2, nil),
        (.immediateOrCancel(price: 3), .immediateOrCancel, 3, nil),
        (.fillOrKill(price: 4), .fillOrKill, 4, nil),
        (.market, .market, nil, nil),
        (.bestPrice(.opposite1), .limit, nil, MexcFutures.BestPrice.opposite1),
    ])
    func `each pricing maps to MEXC's order type`(
        pricing: MexcFutures.OrderRequest.Pricing, type: MexcFutures.OrderType, price: Decimal?,
        bestPrice: MexcFutures.BestPrice?
    ) {
        #expect(pricing.type == type)
        #expect(pricing.price == price)
        #expect(pricing.bestPrice == bestPrice)
    }

    @Test func `options are off unless set`() {
        let options = MexcFutures.OrderRequest.Options()
        #expect(!options.reduceOnly && !options.triggerProtection && !options.marketCeiling && !options.flashClose)
        #expect(options.positionMode == nil && options.selfTradePrevention == nil)
    }
}
