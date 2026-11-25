public import Foundation

// MARK: - Model

extension MexcFutures {
    /// One execution of the account's order.
    ///
    /// Volumes are in contracts. The optional properties are in MEXC's documentation for some fill
    /// endpoints but not others; `nil` means the response didn't include the field.
    public struct Fill: Hashable, Sendable {
        public let id: FillID
        public let symbol: Symbol
        public let order: OrderID?
        public let side: OrderSide
        public let price: Decimal
        public let volume: Decimal
        /// The fee: positive when the account pays it, negative when it receives it.
        public let fee: Decimal
        /// The asset the fee is paid in, such as `"USDT"`.
        public let feeAsset: String
        /// The profit of the volume the fill closed; negative for a loss.
        public let profit: Decimal?
        public let category: OrderCategory?
        /// Whether the fill took liquidity.
        public let isTaker: Bool?
        public let positionMode: PositionMode?
        public let filledAt: Date

        public init(
            id: FillID, symbol: Symbol, order: OrderID?, side: OrderSide, price: Decimal, volume: Decimal,
            fee: Decimal, feeAsset: String, profit: Decimal?, category: OrderCategory?, isTaker: Bool?,
            positionMode: PositionMode?, filledAt: Date
        ) {
            self.id = id
            self.symbol = symbol
            self.order = order
            self.side = side
            self.price = price
            self.volume = volume
            self.fee = fee
            self.feeAsset = feeAsset
            self.profit = profit
            self.category = category
            self.isTaker = isTaker
            self.positionMode = positionMode
            self.filledAt = filledAt
        }
    }
}

// MARK: - Wire

extension MexcFutures.Fill: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, symbol, orderId, side, price, vol, fee, feeCurrency, profit, category, taker, isTaker
        case positionMode, timestamp
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(MexcFutures.FillID.self, forKey: .id)
        symbol = try container.decode(MexcFutures.Symbol.self, forKey: .symbol)
        order = try container.decodeIfPresent(MexcFutures.OrderID.self, forKey: .orderId)
        side = try container.decode(MexcFutures.OrderSide.self, forKey: .side)
        price = try container.decimal(forKey: .price)
        volume = try container.decimal(forKey: .vol)
        fee = try container.decimal(forKey: .fee)
        feeAsset = try container.decode(String.self, forKey: .feeCurrency)
        profit = try container.decimalIfPresent(forKey: .profit)
        category = try container.decodeIfPresent(MexcFutures.OrderCategory.self, forKey: .category)
            .flatMap { $0.rawValue == 0 ? nil : $0 }
        // The examples send `taker`; the field tables name it `isTaker`.
        isTaker = try container.decodeIfPresent(Bool.self, forKey: .taker)
            ?? container.decodeIfPresent(Bool.self, forKey: .isTaker)
        positionMode = try container.decodeIfPresent(MexcFutures.PositionMode.self, forKey: .positionMode)
            .flatMap { $0.rawValue == 0 ? nil : $0 }
        filledAt = try container.millisecondDate(forKey: .timestamp)
    }
}
