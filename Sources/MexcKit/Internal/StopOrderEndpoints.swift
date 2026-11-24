import Foundation

/// The live ``MexcFutures/StopOrderAPI``.
struct StopOrderEndpoints: MexcFutures.StopOrderAPI {
    let rest: RESTClient

    // MARK: - Endpoints

    func place(_ request: MexcFutures.StopOrderRequest) async throws -> MexcFutures.StopOrderID {
        try await rest.send(.post("/api/v1/private/stoporder/place", .json(try StopOrderBody(request))))
    }

    func modify(
        _ id: MexcFutures.StopOrderID, takeProfit: MexcFutures.AttachedStop?, stopLoss: MexcFutures.AttachedStop?
    ) async throws {
        guard takeProfit != nil || stopLoss != nil else {
            throw MexcFutures.ClientError(.invalidRequest, message: "A stop order needs a take-profit or a stop-loss")
        }
        let body = StopPrices(
            stopPlanOrderId: try NumericID(id), orderId: nil, takeProfit: takeProfit, stopLoss: stopLoss
        )
        let _: NoData = try await rest.send(.post("/api/v1/private/stoporder/change_plan_price", .json(body)))
    }

    func setAttachedStops(
        of id: MexcFutures.OrderID, takeProfit: MexcFutures.AttachedStop?, stopLoss: MexcFutures.AttachedStop?
    ) async throws {
        let body = StopPrices(stopPlanOrderId: nil, orderId: try NumericID(id), takeProfit: takeProfit, stopLoss: stopLoss)
        let _: NoData = try await rest.send(.post("/api/v1/private/stoporder/change_price", .json(body)))
    }

    func cancel(_ ids: [MexcFutures.StopOrderID]) async throws {
        let body = try ids.map { Cancellation(stopPlanOrderId: try NumericID($0)) }
        let _: NoData = try await rest.send(.post("/api/v1/private/stoporder/cancel", .json(body)))
    }

    func cancelAll(_ symbol: MexcFutures.Symbol?, position: MexcFutures.PositionID?) async throws {
        // MEXC uses the position when there is one, else the symbol, else cancels in every market.
        let body = Scope(positionId: try position.map(NumericID.init), symbol: symbol)
        let _: NoData = try await rest.send(.post("/api/v1/private/stoporder/cancel_all", .json(body)))
    }

    func pending(_ symbol: MexcFutures.Symbol?) async throws -> [MexcFutures.StopOrder] {
        try await rest.send(.get(
            "/api/v1/private/stoporder/open_orders", query: ["symbol": symbol?.rawValue], authentication: .signed
        ))
    }

    func list(
        _ symbol: MexcFutures.Symbol?, state: MexcFutures.PlanOrderState?, side: MexcFutures.PositionSide?,
        start: Date?, end: Date?, page: MexcFutures.PageRequest
    ) async throws -> [MexcFutures.StopOrder] {
        let orders: ArrayOrPage<MexcFutures.StopOrder> = try await rest.send(
            .get("/api/v1/private/stoporder/list/orders", query: [
                "symbol": symbol?.rawValue,
                "state": state.map { String($0.rawValue) },
                "type": side.map { String($0.rawValue) },
                "start_time": start.map { String($0.millisecondsSince1970) },
                "end_time": end.map { String($0.millisecondsSince1970) },
                "page_num": String(page.number),
                "page_size": String(page.size),
            ], authentication: .signed)
        )
        return orders.items
    }
}

// MARK: - Wire

/// A `stoporder/place` body, with MEXC's field names.
///
/// MEXC marks both trigger price types required, so an exit that isn't set sends the last price (1) as
/// its type. Its documentation also marks the limit
/// prices and their types required, but they only apply to a limit exit, and MEXC's Postman collection
/// leaves them out; they're sent for a limit exit only.
private struct StopOrderBody: Encodable, Sendable {
    let positionId: NumericID
    let vol: Decimal
    let takeProfitPrice: Decimal?
    let profitTrend: MexcFutures.PriceSource
    let takeProfitType: Int?
    let takeProfitOrderPrice: Decimal?
    let stopLossPrice: Decimal?
    let lossTrend: MexcFutures.PriceSource
    let stopLossType: Int?
    let stopLossOrderPrice: Decimal?
    let priceProtect: Int?

    init(_ request: MexcFutures.StopOrderRequest) throws {
        guard request.takeProfit != nil || request.stopLoss != nil else {
            throw MexcFutures.ClientError(.invalidRequest, message: "A stop order needs a take-profit or a stop-loss")
        }
        positionId = try NumericID(request.position)
        vol = request.volume
        takeProfitPrice = request.takeProfit?.price
        profitTrend = request.takeProfit?.source ?? .last
        takeProfitType = request.takeProfit?.limitPrice.map { _ in 1 }
        takeProfitOrderPrice = request.takeProfit?.limitPrice
        stopLossPrice = request.stopLoss?.price
        lossTrend = request.stopLoss?.source ?? .last
        stopLossType = request.stopLoss?.limitPrice.map { _ in 1 }
        stopLossOrderPrice = request.stopLoss?.limitPrice
        priceProtect = request.triggerProtection ? 1 : nil
    }
}

/// A `change_plan_price` or `change_price` body: the stop order or the limit order, and its new prices.
/// A price left out removes that stop.
private struct StopPrices: Encodable, Sendable {
    let stopPlanOrderId: NumericID?
    let orderId: NumericID?
    let takeProfitPrice: Decimal?
    let profitTrend: MexcFutures.PriceSource?
    let stopLossPrice: Decimal?
    let lossTrend: MexcFutures.PriceSource?

    init(
        stopPlanOrderId: NumericID?, orderId: NumericID?, takeProfit: MexcFutures.AttachedStop?,
        stopLoss: MexcFutures.AttachedStop?
    ) {
        self.stopPlanOrderId = stopPlanOrderId
        self.orderId = orderId
        takeProfitPrice = takeProfit?.price
        profitTrend = takeProfit?.source
        stopLossPrice = stopLoss?.price
        lossTrend = stopLoss?.source
    }
}

private struct Cancellation: Encodable, Sendable {
    let stopPlanOrderId: NumericID
}

private struct Scope: Encodable, Sendable {
    let positionId: NumericID?
    let symbol: MexcFutures.Symbol?
}
