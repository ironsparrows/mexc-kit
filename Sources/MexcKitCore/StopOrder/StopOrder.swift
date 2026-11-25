public import Foundation

// MARK: - Model

extension MexcFutures {
    /// A stop order: a take-profit, a stop-loss or both on a position.
    ///
    /// Volumes are in contracts. The optional properties are in MEXC's documentation but not in every
    /// documented example; `nil` means the response didn't include the field, or sent 0 for none.
    ///
    /// Not exposed: separate take-profit and stop-loss volumes (`profitLossVolType`, `takeProfitVol`,
    /// `stopLossVol`), partial or whole-position stops (`volType`), reversing on trigger
    /// (`takeProfitReverse`, `stopLossReverse`) and `version`.
    public struct StopOrder: Hashable, Sendable {
        public let id: StopOrderID
        public let symbol: Symbol
        /// The position the stop order is on; `nil` when MEXC reports none (0).
        public let position: PositionID?
        public let side: PositionSide
        /// The limit order the stop order came with; `nil` when it was placed on the position.
        public let order: OrderID?
        public let takeProfit: Exit?
        public let stopLoss: Exit?
        public let volume: Decimal
        public let state: PlanOrderState
        /// Whether MEXC counts the stop order as final.
        public let isFinished: Bool
        /// Which exit triggered; `nil` while none has.
        public let triggered: Leg?
        /// The volume MEXC placed when the stop order triggered.
        public let placedVolume: Decimal?
        /// The order MEXC placed when the stop order triggered.
        public let placedOrder: OrderID?
        /// Why placing the order failed, as MEXC reports it.
        public let errorCode: MexcError.Code?
        /// MEXC's trigger protection.
        public let triggerProtection: Bool?
        public let createdAt: Date
        public let updatedAt: Date?

        public init(
            id: StopOrderID, symbol: Symbol, position: PositionID?, side: PositionSide, order: OrderID?,
            takeProfit: Exit?, stopLoss: Exit?, volume: Decimal, state: PlanOrderState, isFinished: Bool,
            triggered: Leg?, placedVolume: Decimal?, placedOrder: OrderID?, errorCode: MexcError.Code?,
            triggerProtection: Bool?, createdAt: Date, updatedAt: Date?
        ) {
            self.id = id
            self.symbol = symbol
            self.position = position
            self.side = side
            self.order = order
            self.takeProfit = takeProfit
            self.stopLoss = stopLoss
            self.volume = volume
            self.state = state
            self.isFinished = isFinished
            self.triggered = triggered
            self.placedVolume = placedVolume
            self.placedOrder = placedOrder
            self.errorCode = errorCode
            self.triggerProtection = triggerProtection
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }
}

// MARK: - Exit

extension MexcFutures.StopOrder {
    /// A take-profit or a stop-loss: the price that triggers it, and how the closing order is priced.
    public struct Exit: Hashable, Sendable {
        /// The trigger price.
        public let price: Decimal
        /// The price MEXC compares with ``price``.
        public let source: MexcFutures.PriceSource
        /// The price of the closing limit order; `nil` for a market order.
        public let limitPrice: Decimal?

        public init(price: Decimal, source: MexcFutures.PriceSource = .last, limitPrice: Decimal? = nil) {
            self.price = price
            self.source = source
            self.limitPrice = limitPrice
        }

        /// Closes at the market once the price MEXC watches reaches `price`.
        public static func market(at price: Decimal, source: MexcFutures.PriceSource = .last) -> Self {
            Self(price: price, source: source)
        }

        /// Places a closing limit order at `limitPrice` once the price MEXC watches reaches `price`.
        public static func limit(
            _ limitPrice: Decimal, at price: Decimal, source: MexcFutures.PriceSource = .last
        ) -> Self {
            Self(price: price, source: source, limitPrice: limitPrice)
        }
    }
}

// MARK: - Leg

extension MexcFutures.StopOrder {
    /// Which exit of a stop order triggered.
    public struct Leg: RawRepresentable, Hashable, Sendable, Codable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let takeProfit = Self(rawValue: 1)
        public static let stopLoss = Self(rawValue: 2)
    }
}

// MARK: - Wire

extension MexcFutures.StopOrder: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, symbol, positionId, positionType, orderId, takeProfitPrice, profitTrend, takeProfitType
        case takeProfitOrderPrice, stopLossPrice, lossTrend, stopLossType, stopLossOrderPrice, vol, state, isFinished
        case triggerSide, realityVol, placeOrderId, errorCode, priceProtect, createTime, updateTime
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(MexcFutures.StopOrderID.self, forKey: .id)
        symbol = try container.decode(MexcFutures.Symbol.self, forKey: .symbol)
        position = try container.nonZeroIfPresent(MexcFutures.PositionID.self, forKey: .positionId)
        side = try container.decode(MexcFutures.PositionSide.self, forKey: .positionType)
        order = try container.nonZeroIfPresent(MexcFutures.OrderID.self, forKey: .orderId)
        takeProfit = try Self.exit(
            in: container, price: .takeProfitPrice, source: .profitTrend, type: .takeProfitType,
            limitPrice: .takeProfitOrderPrice
        )
        stopLoss = try Self.exit(
            in: container, price: .stopLossPrice, source: .lossTrend, type: .stopLossType,
            limitPrice: .stopLossOrderPrice
        )
        volume = try container.decimal(forKey: .vol)
        state = try container.decode(MexcFutures.PlanOrderState.self, forKey: .state)
        isFinished = try container.decode(Int.self, forKey: .isFinished) == 1
        triggered = try container.decodeIfPresent(Leg.self, forKey: .triggerSide).flatMap { $0.rawValue == 0 ? nil : $0 }
        placedVolume = try container.decimalIfPresent(forKey: .realityVol)
        placedOrder = try container.nonZeroIfPresent(MexcFutures.OrderID.self, forKey: .placeOrderId)
        errorCode = try container.decodeIfPresent(Int.self, forKey: .errorCode)
            .flatMap { $0 == 0 ? nil : MexcError.Code(rawValue: $0) }
        triggerProtection = try container.decodeIfPresent(Int.self, forKey: .priceProtect).map { $0 == 1 }
        createdAt = try container.millisecondDate(forKey: .createTime)
        updatedAt = try container.millisecondDateIfPresent(forKey: .updateTime)
    }

    /// An exit; `nil` when its price is missing or 0. Its type 1 is a limit order at the order price.
    private static func exit(
        in container: KeyedDecodingContainer<CodingKeys>, price: CodingKeys, source: CodingKeys, type: CodingKeys,
        limitPrice: CodingKeys
    ) throws -> Exit? {
        guard let stop = try container.attachedStop(price: price, source: source) else { return nil }
        let isLimit = try container.decodeIfPresent(Int.self, forKey: type) == 1
        return Exit(
            price: stop.price, source: stop.source,
            limitPrice: isLimit ? try container.decimalIfPresent(forKey: limitPrice) : nil
        )
    }
}
