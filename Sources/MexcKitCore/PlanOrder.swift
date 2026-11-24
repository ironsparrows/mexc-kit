public import Foundation

// MARK: - Model

extension MexcFutures {
    /// A plan order: an order MEXC places once its trigger price is reached.
    ///
    /// Volumes are in contracts. The optional properties are in MEXC's documentation but not in every
    /// documented example; `nil` means the response didn't include the field, or sent 0 for none.
    public struct PlanOrder: Hashable, Sendable {
        public let id: PlanOrderID
        public let symbol: Symbol
        public let side: OrderSide
        public let type: OrderType
        public let marginMode: MarginMode
        public let leverage: Int
        public let trigger: Trigger
        /// The price of the order placed when the trigger is reached; `nil` when MEXC sends none.
        public let price: Decimal?
        public let volume: Decimal
        public let state: PlanOrderState
        /// How long MEXC keeps the plan order waiting for its trigger.
        public let lifetime: Duration
        public let takeProfit: AttachedStop?
        public let stopLoss: AttachedStop?
        /// The order MEXC placed when the trigger was reached.
        public let order: OrderID?
        /// Why placing the order failed, as MEXC reports it.
        public let errorCode: MexcError.Code?
        public let positionMode: PositionMode?
        public let reduceOnly: Bool?
        /// MEXC's trigger protection.
        public let triggerProtection: Bool?
        public let createdAt: Date
        public let updatedAt: Date?

        public init(
            id: PlanOrderID, symbol: Symbol, side: OrderSide, type: OrderType, marginMode: MarginMode, leverage: Int,
            trigger: Trigger, price: Decimal?, volume: Decimal, state: PlanOrderState, lifetime: Duration,
            takeProfit: AttachedStop?, stopLoss: AttachedStop?, order: OrderID?, errorCode: MexcError.Code?,
            positionMode: PositionMode?, reduceOnly: Bool?, triggerProtection: Bool?, createdAt: Date,
            updatedAt: Date?
        ) {
            self.id = id
            self.symbol = symbol
            self.side = side
            self.type = type
            self.marginMode = marginMode
            self.leverage = leverage
            self.trigger = trigger
            self.price = price
            self.volume = volume
            self.state = state
            self.lifetime = lifetime
            self.takeProfit = takeProfit
            self.stopLoss = stopLoss
            self.order = order
            self.errorCode = errorCode
            self.positionMode = positionMode
            self.reduceOnly = reduceOnly
            self.triggerProtection = triggerProtection
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }
}

// MARK: - Wire

extension MexcFutures.PlanOrder: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, symbol, side, orderType, openType, leverage, triggerPrice, triggerType, trend, price, vol, state
        case executeCycle, takeProfitPrice, profitTrend, stopLossPrice, lossTrend, orderId, errorCode, positionMode
        case reduceOnly, priceProtect, createTime, updateTime
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(MexcFutures.PlanOrderID.self, forKey: .id)
        symbol = try container.decode(MexcFutures.Symbol.self, forKey: .symbol)
        side = try container.decode(MexcFutures.OrderSide.self, forKey: .side)
        type = try container.decode(MexcFutures.OrderType.self, forKey: .orderType)
        marginMode = try container.decode(MexcFutures.MarginMode.self, forKey: .openType)
        leverage = try container.decode(Int.self, forKey: .leverage)
        trigger = MexcFutures.Trigger(
            price: try container.decimal(forKey: .triggerPrice),
            condition: try container.decode(MexcFutures.TriggerCondition.self, forKey: .triggerType),
            source: try container.decode(MexcFutures.PriceSource.self, forKey: .trend)
        )
        price = try container.decimalIfPresent(forKey: .price)
        volume = try container.decimal(forKey: .vol)
        state = try container.decode(MexcFutures.PlanOrderState.self, forKey: .state)
        lifetime = .seconds(try container.decode(Int.self, forKey: .executeCycle) * 3600)
        takeProfit = try container.attachedStop(price: .takeProfitPrice, source: .profitTrend)
        stopLoss = try container.attachedStop(price: .stopLossPrice, source: .lossTrend)
        order = try container.nonZeroIfPresent(MexcFutures.OrderID.self, forKey: .orderId)
        errorCode = try container.decodeIfPresent(Int.self, forKey: .errorCode)
            .flatMap { $0 == 0 ? nil : MexcError.Code(rawValue: $0) }
        positionMode = try container.decodeIfPresent(MexcFutures.PositionMode.self, forKey: .positionMode)
            .flatMap { $0.rawValue == 0 ? nil : $0 }
        reduceOnly = try container.decodeIfPresent(Bool.self, forKey: .reduceOnly)
        triggerProtection = try container.decodeIfPresent(Int.self, forKey: .priceProtect).map { $0 == 1 }
        createdAt = try container.millisecondDate(forKey: .createTime)
        updatedAt = try container.millisecondDateIfPresent(forKey: .updateTime)
    }
}
