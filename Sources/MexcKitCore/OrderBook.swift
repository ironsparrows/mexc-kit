public import Foundation

// MARK: - Model

extension MexcFutures {
    /// A market's order book: the price levels on each side, best first.
    public struct OrderBook: Hashable, Sendable {
        /// Sell orders, lowest price first.
        public let asks: [Level]
        /// Buy orders, highest price first.
        public let bids: [Level]
        /// The book's version. Each change raises it.
        public let version: Int64
        public let time: Date

        public init(asks: [Level], bids: [Level], version: Int64, time: Date) {
            self.asks = asks
            self.bids = bids
            self.version = version
            self.time = time
        }
    }
}

extension MexcFutures.OrderBook {
    /// The orders at one price.
    public struct Level: Hashable, Sendable {
        public let price: Decimal
        /// The volume at this price, in contracts.
        public let volume: Decimal
        /// The number of orders at this price.
        public let orderCount: Int

        public init(price: Decimal, volume: Decimal, orderCount: Int) {
            self.price = price
            self.volume = volume
            self.orderCount = orderCount
        }
    }

    /// The levels one version of the book changed: each level's new volume.
    public struct Change: Hashable, Sendable {
        public let asks: [Level]
        public let bids: [Level]
        /// The version the book has after this change.
        public let version: Int64

        public init(asks: [Level], bids: [Level], version: Int64) {
            self.asks = asks
            self.bids = bids
            self.version = version
        }
    }
}

// MARK: - Wire

extension MexcFutures.OrderBook: Decodable {
    private enum CodingKeys: String, CodingKey {
        case asks, bids, version, timestamp
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        asks = try container.decode([Level].self, forKey: .asks)
        bids = try container.decode([Level].self, forKey: .bids)
        version = try container.decode(Int64.self, forKey: .version)
        time = try container.millisecondDate(forKey: .timestamp)
    }
}

extension MexcFutures.OrderBook.Change: Decodable {
    private enum CodingKeys: String, CodingKey {
        case asks, bids, version
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        asks = try container.decode([MexcFutures.OrderBook.Level].self, forKey: .asks)
        bids = try container.decode([MexcFutures.OrderBook.Level].self, forKey: .bids)
        version = try container.decode(Int64.self, forKey: .version)
    }
}

extension MexcFutures.OrderBook.Level: Decodable {
    /// Decodes `[price, volume, orderCount]`.
    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        price = try container.decode(FlexibleDecimal.self).value
        volume = try container.decode(FlexibleDecimal.self).value
        orderCount = try container.decode(Int.self)
    }
}
