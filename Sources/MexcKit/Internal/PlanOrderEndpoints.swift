import Foundation

/// The live ``MexcFutures/PlanOrderAPI``.
struct PlanOrderEndpoints: MexcFutures.PlanOrderAPI {
    let rest: RESTClient

    // MARK: - Endpoints

    func place(_ request: MexcFutures.PlanOrderRequest) async throws -> MexcFutures.PlanOrderID {
        try await rest.send(.post("/api/v1/private/planorder/place/v2", .json(try PlanOrderBody(request))))
    }

    func modify(
        _ id: MexcFutures.PlanOrderID, in symbol: MexcFutures.Symbol, trigger: MexcFutures.Trigger,
        pricing: MexcFutures.OrderRequest.Pricing
    ) async throws {
        try PlanOrderBody.reject(pricing)
        // MEXC requires a price here, even for a market order.
        guard let price = pricing.price else {
            throw MexcFutures.ClientError(.invalidRequest, message: "Changing a plan order needs a limit price")
        }
        // MEXC also lists a required `from`, which says where in MEXC's own apps a change was made ("empty
        // means price modified via kline drag"); it has no value for an API client, so none is sent.
        let body = Modification(
            symbol: symbol, orderId: try NumericID(id), triggerPrice: trigger.price, price: price,
            orderType: pricing.type, triggerType: trigger.condition, trend: trigger.source
        )
        let _: NoData = try await rest.send(.post("/api/v1/private/planorder/change_price", .json(body)))
    }

    func setAttachedStops(
        of id: MexcFutures.PlanOrderID, in symbol: MexcFutures.Symbol, takeProfit: MexcFutures.AttachedStop?,
        stopLoss: MexcFutures.AttachedStop?
    ) async throws {
        let body = AttachedStops(
            symbol: symbol, orderId: try NumericID(id), takeProfitPrice: takeProfit?.price,
            profitTrend: takeProfit?.source, stopLossPrice: stopLoss?.price, lossTrend: stopLoss?.source
        )
        let _: NoData = try await rest.send(.post("/api/v1/private/planorder/change_stop_order", .json(body)))
    }

    func cancel(_ ids: [MexcFutures.PlanOrderID], in symbol: MexcFutures.Symbol) async throws {
        let body = try ids.map { Cancellation(symbol: symbol, orderId: try NumericID($0).value) }
        let _: NoData = try await rest.send(.post("/api/v1/private/planorder/cancel", .json(body)))
    }

    func cancelAll(_ symbol: MexcFutures.Symbol?) async throws {
        // Without a symbol the body is `{}`, and MEXC cancels the plan orders of every market.
        let _: NoData = try await rest.send(.post("/api/v1/private/planorder/cancel_all", .json(Market(symbol: symbol))))
    }

    func list(
        _ symbol: MexcFutures.Symbol?, states: [MexcFutures.PlanOrderState], side: MexcFutures.OrderSide?,
        start: Date, end: Date, page: MexcFutures.PageRequest
    ) async throws -> [MexcFutures.PlanOrder] {
        let orders: ArrayOrPage<MexcFutures.PlanOrder> = try await rest.send(
            .get("/api/v1/private/planorder/list/orders", query: [
                "symbol": symbol?.rawValue,
                "states": states.isEmpty ? nil : states.map { String($0.rawValue) }.joined(separator: ","),
                "side": side.map { String($0.rawValue) },
                "start_time": String(start.millisecondsSince1970),
                "end_time": String(end.millisecondsSince1970),
                "page_num": String(page.number),
                "page_size": String(page.size),
            ], authentication: .signed)
        )
        return orders.items
    }
}

// MARK: - Wire

/// A `place/v2` plan order, with MEXC's field names.
private struct PlanOrderBody: Encodable, Sendable {
    let symbol: MexcFutures.Symbol
    let side: MexcFutures.OrderSide
    let orderType: MexcFutures.OrderType
    let price: Decimal?
    let vol: Decimal
    let leverage: Int?
    let openType: MexcFutures.MarginMode
    let triggerPrice: Decimal
    let triggerType: MexcFutures.TriggerCondition
    let trend: MexcFutures.PriceSource
    let executeCycle: MexcFutures.PlanOrderRequest.Lifetime
    let takeProfitPrice: Decimal?
    let profitTrend: MexcFutures.PriceSource?
    let stopLossPrice: Decimal?
    let lossTrend: MexcFutures.PriceSource?
    let positionMode: MexcFutures.PositionMode?
    let reduceOnly: Bool?
    let priceProtect: Int?

    /// The fields of `request`, leaving out every option that isn't set.
    init(_ request: MexcFutures.PlanOrderRequest) throws {
        try Self.reject(request.pricing)
        symbol = request.symbol
        side = request.side
        orderType = request.pricing.type
        price = request.pricing.price
        vol = request.volume
        leverage = request.leverage
        openType = request.marginMode
        triggerPrice = request.trigger.price
        triggerType = request.trigger.condition
        trend = request.trigger.source
        executeCycle = request.lifetime
        takeProfitPrice = request.takeProfit?.price
        profitTrend = request.takeProfit?.source
        stopLossPrice = request.stopLoss?.price
        lossTrend = request.stopLoss?.source
        positionMode = request.options.positionMode
        reduceOnly = request.options.reduceOnly ? true : nil
        priceProtect = request.options.triggerProtection ? 1 : nil
    }

    /// Throws ``MexcFutures/ClientError/Reason/invalidRequest`` for a best price, which MEXC's plan
    /// orders don't take.
    static func reject(_ pricing: MexcFutures.OrderRequest.Pricing) throws {
        if pricing.bestPrice != nil {
            throw MexcFutures.ClientError(.invalidRequest, message: "A plan order can't have a best price")
        }
    }
}

private struct Modification: Encodable, Sendable {
    let symbol: MexcFutures.Symbol
    let orderId: NumericID
    let triggerPrice: Decimal
    let price: Decimal
    let orderType: MexcFutures.OrderType
    let triggerType: MexcFutures.TriggerCondition
    let trend: MexcFutures.PriceSource
}

/// A `change_stop_order` body. A price left out removes that stop.
private struct AttachedStops: Encodable, Sendable {
    let symbol: MexcFutures.Symbol
    let orderId: NumericID
    let takeProfitPrice: Decimal?
    let profitTrend: MexcFutures.PriceSource?
    let stopLossPrice: Decimal?
    let lossTrend: MexcFutures.PriceSource?
}

/// One item of a `cancel` body. MEXC's table types `orderId` as a string and its example sends a
/// number; it's sent as the table says, after checking it's numeric.
private struct Cancellation: Encodable, Sendable {
    let symbol: MexcFutures.Symbol
    let orderId: String

    init(symbol: MexcFutures.Symbol, orderId: Int64) {
        self.symbol = symbol
        self.orderId = String(orderId)
    }
}

private struct Market: Encodable, Sendable {
    let symbol: MexcFutures.Symbol?
}
