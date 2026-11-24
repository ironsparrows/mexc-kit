public import Foundation

// MARK: - Model

extension MexcFutures {
    /// A trailing order: once active, MEXC follows the highest or lowest price reached, moves the
    /// trigger price with it, and places an order when the trigger is reached.
    ///
    /// Volumes are in contracts. The optional properties are in MEXC's documentation but not in every
    /// documented example; `nil` means the response didn't include the field, or sent 0 for none.
    ///
    /// ``errorCode``, like the other conditional orders', reads MEXC's number against its error code
    /// table, which the stop orders' documentation points to; MEXC doesn't say which table applies here.
    public struct TrailingOrder: Hashable, Sendable {
        public let id: TrailingOrderID
        public let symbol: Symbol
        public let side: OrderSide
        public let marginMode: MarginMode
        public let leverage: Int
        public let volume: Decimal
        /// The price MEXC follows.
        public let source: PriceSource
        public let callback: Callback
        /// MEXC's activation price; `nil` when MEXC reports none (0).
        public let activationPrice: Decimal?
        /// MEXC's reference price: the highest or lowest price since the order became active.
        public let referencePrice: Decimal?
        /// The price that triggers the order, which moves with the reference price.
        public let triggerPrice: Decimal?
        public let triggerCondition: TriggerCondition?
        public let state: TrailingOrderState
        /// The order MEXC placed when the trailing order triggered.
        public let order: OrderID?
        /// Why the trigger failed, as MEXC reports it.
        public let errorCode: MexcError.Code?
        public let positionMode: PositionMode?
        public let reduceOnly: Bool?
        public let createdAt: Date
        public let updatedAt: Date?

        public init(
            id: TrailingOrderID, symbol: Symbol, side: OrderSide, marginMode: MarginMode, leverage: Int,
            volume: Decimal, source: PriceSource, callback: Callback, activationPrice: Decimal?,
            referencePrice: Decimal?, triggerPrice: Decimal?, triggerCondition: TriggerCondition?,
            state: TrailingOrderState, order: OrderID?, errorCode: MexcError.Code?, positionMode: PositionMode?,
            reduceOnly: Bool?, createdAt: Date, updatedAt: Date?
        ) {
            self.id = id
            self.symbol = symbol
            self.side = side
            self.marginMode = marginMode
            self.leverage = leverage
            self.volume = volume
            self.source = source
            self.callback = callback
            self.activationPrice = activationPrice
            self.referencePrice = referencePrice
            self.triggerPrice = triggerPrice
            self.triggerCondition = triggerCondition
            self.state = state
            self.order = order
            self.errorCode = errorCode
            self.positionMode = positionMode
            self.reduceOnly = reduceOnly
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }
}

// MARK: - Callback

extension MexcFutures.TrailingOrder {
    /// How far the price must move back from the reference price to trigger the order.
    public struct Callback: Hashable, Sendable {
        public let kind: Kind
        /// The callback value, as MEXC takes it.
        public let value: Decimal

        public init(kind: Kind, value: Decimal) {
            self.kind = kind
            self.value = value
        }

        /// A callback MEXC calls a percentage. Its documentation doesn't say whether `0.02` means 2 %
        /// or 0.02 %; its example sends `0.02`.
        public static func percentage(_ value: Decimal) -> Self { Self(kind: .percentage, value: value) }

        /// A callback MEXC calls an absolute value: a price distance.
        public static func distance(_ value: Decimal) -> Self { Self(kind: .distance, value: value) }

        /// Whether a callback is a percentage or a price distance.
        public struct Kind: RawRepresentable, Hashable, Sendable, Codable {
            public let rawValue: Int
            public init(rawValue: Int) { self.rawValue = rawValue }

            public static let percentage = Self(rawValue: 1)
            /// MEXC's "absolute value".
            public static let distance = Self(rawValue: 2)
        }
    }
}

// MARK: - Wire

extension MexcFutures.TrailingOrder: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, symbol, side, openType, leverage, vol, trend, backType, backValue, activePrice, markPrice
        case triggerPrice, triggerType, state, orderId, errorCode, positionMode, reduceOnly, createTime, updateTime
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(MexcFutures.TrailingOrderID.self, forKey: .id)
        symbol = try container.decode(MexcFutures.Symbol.self, forKey: .symbol)
        side = try container.decode(MexcFutures.OrderSide.self, forKey: .side)
        marginMode = try container.decode(MexcFutures.MarginMode.self, forKey: .openType)
        leverage = try container.decode(Int.self, forKey: .leverage)
        volume = try container.decimal(forKey: .vol)
        source = try container.decode(MexcFutures.PriceSource.self, forKey: .trend)
        callback = Callback(
            kind: try container.decode(Callback.Kind.self, forKey: .backType),
            value: try container.decimal(forKey: .backValue)
        )
        activationPrice = try container.decimalIfPresent(forKey: .activePrice).flatMap { $0 == 0 ? nil : $0 }
        referencePrice = try container.decimalIfPresent(forKey: .markPrice)
        triggerPrice = try container.decimalIfPresent(forKey: .triggerPrice)
        triggerCondition = try container.decodeIfPresent(MexcFutures.TriggerCondition.self, forKey: .triggerType)
            .flatMap { $0.rawValue == 0 ? nil : $0 }
        state = try container.decode(MexcFutures.TrailingOrderState.self, forKey: .state)
        order = try container.nonZeroIfPresent(MexcFutures.OrderID.self, forKey: .orderId)
        errorCode = try container.decodeIfPresent(Int.self, forKey: .errorCode)
            .flatMap { $0 == 0 ? nil : MexcError.Code(rawValue: $0) }
        positionMode = try container.decodeIfPresent(MexcFutures.PositionMode.self, forKey: .positionMode)
            .flatMap { $0.rawValue == 0 ? nil : $0 }
        reduceOnly = try container.decodeIfPresent(Bool.self, forKey: .reduceOnly)
        createdAt = try container.millisecondDate(forKey: .createTime)
        updatedAt = try container.millisecondDateIfPresent(forKey: .updateTime)
    }
}
