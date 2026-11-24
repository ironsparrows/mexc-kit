public import Foundation

// MARK: - Model

extension MexcFutures {
    /// One public trade in a market.
    public struct Deal: Hashable, Sendable {
        /// MEXC's ID for the trade, when the response includes one.
        public let id: String?
        public let price: Decimal
        /// The volume traded, in contracts.
        public let volume: Decimal
        /// Whether the taker bought or sold.
        public let takerSide: TakerSide
        public let positionEffect: PositionEffect
        /// Whether the taker and the maker are the same account.
        ///
        /// MEXC documents its flag this way: 1 is a self-trade, 2 isn't. In public trades read on
        /// 2026-11-24, about half carried it, from the stream and the REST endpoint alike, so don't
        /// rely on it until it's verified.
        public let isSelfTrade: Bool
        public let time: Date

        public init(
            id: String?, price: Decimal, volume: Decimal, takerSide: TakerSide, positionEffect: PositionEffect,
            isSelfTrade: Bool, time: Date
        ) {
            self.id = id
            self.price = price
            self.volume = volume
            self.takerSide = takerSide
            self.positionEffect = positionEffect
            self.isSelfTrade = isSelfTrade
            self.time = time
        }
    }
}

extension MexcFutures.Deal {
    /// Whether a trade's taker bought or sold.
    public struct TakerSide: RawRepresentable, Hashable, Sendable, Codable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let buy = Self(rawValue: 1)
        public static let sell = Self(rawValue: 2)
    }

    /// What a trade did to open interest.
    public struct PositionEffect: RawRepresentable, Hashable, Sendable, Codable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        /// Both the taker and the maker opened positions, so open interest grew by the trade's volume.
        public static let bothOpened = Self(rawValue: 1)
        /// Neither the taker nor the maker opened a position.
        public static let neitherOpened = Self(rawValue: 2)
        /// One side opened a position and the other didn't.
        public static let mixed = Self(rawValue: 3)
    }
}

// MARK: - Wire

extension MexcFutures.Deal: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id = "i"
        case price = "p"
        case volume = "v"
        case takerSide = "T"
        case positionEffect = "O"
        case selfTrade = "M"
        case time = "t"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(FlexibleString.self, forKey: .id)?.value
        price = try container.decimal(forKey: .price)
        volume = try container.decimal(forKey: .volume)
        takerSide = try container.decode(TakerSide.self, forKey: .takerSide)
        positionEffect = try container.decode(PositionEffect.self, forKey: .positionEffect)
        isSelfTrade = try container.decode(Int.self, forKey: .selfTrade) == 1
        time = try container.millisecondDate(forKey: .time)
    }
}
