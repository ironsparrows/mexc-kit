public import Foundation

// MARK: - Model

extension MexcFutures {
    /// An order: pending, or final in the order history.
    ///
    /// Volumes are in contracts. The optional properties are in MEXC's documentation but not on every
    /// endpoint that returns orders; `nil` means the response didn't include the field.
    public struct Order: Hashable, Sendable {
        public let id: OrderID
        public let symbol: Symbol
        /// The position the order belongs to; `nil` when MEXC reports none (0), as for an order that
        /// hasn't filled.
        public let position: PositionID?
        public let side: OrderSide
        public let type: OrderType
        public let category: OrderCategory
        public let state: OrderState
        public let marginMode: MarginMode
        public let leverage: Int
        /// The order price, at full precision.
        public let price: Decimal
        public let volume: Decimal
        public let filledVolume: Decimal
        /// The average fill price, at full precision; `nil` when MEXC reports none (0), as for an order
        /// that hasn't filled.
        public let averageFillPrice: Decimal?
        /// The margin the order reserves.
        public let margin: Decimal
        public let usedMargin: Decimal?
        public let takerFee: Decimal
        public let makerFee: Decimal
        public let totalFee: Decimal?
        /// The asset fees are paid in, such as `"USDT"`.
        public let feeAsset: String
        /// The profit of the volume the order closed; negative for a loss.
        public let profit: Decimal
        public let takeProfit: AttachedStop?
        public let stopLoss: AttachedStop?
        /// The best-price level; `nil` unless the order is a best-price order.
        public let bestPrice: BestPrice?
        public let externalID: ExternalOrderID?
        /// Why MEXC rejected or ended the order; ``OrderErrorCode/normal`` when it didn't.
        public let errorCode: OrderErrorCode?
        public let positionMode: PositionMode?
        public let reduceOnly: Bool?
        /// MEXC's trigger protection for the attached take-profit and stop-loss.
        public let triggerProtection: Bool?
        public let createdAt: Date
        public let updatedAt: Date?

        public init(
            id: OrderID, symbol: Symbol, position: PositionID?, side: OrderSide, type: OrderType,
            category: OrderCategory, state: OrderState, marginMode: MarginMode, leverage: Int, price: Decimal,
            volume: Decimal, filledVolume: Decimal, averageFillPrice: Decimal?, margin: Decimal, usedMargin: Decimal?,
            takerFee: Decimal, makerFee: Decimal, totalFee: Decimal?, feeAsset: String, profit: Decimal,
            takeProfit: AttachedStop?, stopLoss: AttachedStop?, bestPrice: BestPrice?, externalID: ExternalOrderID?,
            errorCode: OrderErrorCode?, positionMode: PositionMode?, reduceOnly: Bool?, triggerProtection: Bool?,
            createdAt: Date, updatedAt: Date?
        ) {
            self.id = id
            self.symbol = symbol
            self.position = position
            self.side = side
            self.type = type
            self.category = category
            self.state = state
            self.marginMode = marginMode
            self.leverage = leverage
            self.price = price
            self.volume = volume
            self.filledVolume = filledVolume
            self.averageFillPrice = averageFillPrice
            self.margin = margin
            self.usedMargin = usedMargin
            self.takerFee = takerFee
            self.makerFee = makerFee
            self.totalFee = totalFee
            self.feeAsset = feeAsset
            self.profit = profit
            self.takeProfit = takeProfit
            self.stopLoss = stopLoss
            self.bestPrice = bestPrice
            self.externalID = externalID
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

extension MexcFutures.Order: Decodable {
    private enum CodingKeys: String, CodingKey {
        case orderId, symbol, positionId, side, orderType, category, state, openType, leverage, price, priceStr
        case vol, dealVol, dealAvgPrice, dealAvgPriceStr, orderMargin, usedMargin, takerFee, makerFee, totalFee
        case feeCurrency, profit, takeProfitPrice, profitTrend, stopLossPrice, lossTrend, bboTypeNum, externalOid
        case errorCode, positionMode, reduceOnly, priceProtect, createTime, updateTime
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(MexcFutures.OrderID.self, forKey: .orderId)
        symbol = try container.decode(MexcFutures.Symbol.self, forKey: .symbol)
        position = try container.nonZeroIfPresent(MexcFutures.PositionID.self, forKey: .positionId)
        side = try container.decode(MexcFutures.OrderSide.self, forKey: .side)
        type = try container.decode(MexcFutures.OrderType.self, forKey: .orderType)
        category = try container.decode(MexcFutures.OrderCategory.self, forKey: .category)
        state = try container.decode(MexcFutures.OrderState.self, forKey: .state)
        marginMode = try container.decode(MexcFutures.MarginMode.self, forKey: .openType)
        leverage = try container.decode(Int.self, forKey: .leverage)
        // The `Str` strings carry digits the plain numbers may round away.
        price = try container.decimalIfPresent(forKey: .priceStr) ?? container.decimal(forKey: .price)
        volume = try container.decimal(forKey: .vol)
        filledVolume = try container.decimal(forKey: .dealVol)
        averageFillPrice = try (container.decimalIfPresent(forKey: .dealAvgPriceStr)
            ?? container.decimalIfPresent(forKey: .dealAvgPrice)).flatMap { $0 == 0 ? nil : $0 }
        margin = try container.decimal(forKey: .orderMargin)
        usedMargin = try container.decimalIfPresent(forKey: .usedMargin)
        takerFee = try container.decimal(forKey: .takerFee)
        makerFee = try container.decimal(forKey: .makerFee)
        totalFee = try container.decimalIfPresent(forKey: .totalFee)
        feeAsset = try container.decode(String.self, forKey: .feeCurrency)
        profit = try container.decimal(forKey: .profit)
        takeProfit = try container.attachedStop(price: .takeProfitPrice, source: .profitTrend)
        stopLoss = try container.attachedStop(price: .stopLossPrice, source: .lossTrend)
        bestPrice = try container.decodeIfPresent(MexcFutures.BestPrice.self, forKey: .bboTypeNum)
            .flatMap { $0.rawValue == 0 ? nil : $0 }
        externalID = try container.decodeIfPresent(MexcFutures.ExternalOrderID.self, forKey: .externalOid)
        errorCode = try container.decodeIfPresent(MexcFutures.OrderErrorCode.self, forKey: .errorCode)
        positionMode = try container.decodeIfPresent(MexcFutures.PositionMode.self, forKey: .positionMode)
            .flatMap { $0.rawValue == 0 ? nil : $0 }
        reduceOnly = try container.decodeIfPresent(Bool.self, forKey: .reduceOnly)
        triggerProtection = try container.decodeIfPresent(Int.self, forKey: .priceProtect).map { $0 == 1 }
        createdAt = try container.millisecondDate(forKey: .createTime)
        updatedAt = try container.millisecondDateIfPresent(forKey: .updateTime)
    }
}
