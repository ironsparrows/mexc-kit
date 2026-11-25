// MARK: - Model

extension MexcFutures {
    /// How many orders of each kind are pending.
    public struct PendingOrderCounts: Hashable, Sendable {
        public let total: Int
        /// MEXC's count of limit orders.
        public let limitOrders: Int
        public let stopOrders: Int
        public let planOrders: Int
        public let trailingOrders: Int

        public init(total: Int, limitOrders: Int, stopOrders: Int, planOrders: Int, trailingOrders: Int) {
            self.total = total
            self.limitOrders = limitOrders
            self.stopOrders = stopOrders
            self.planOrders = planOrders
            self.trailingOrders = trailingOrders
        }
    }
}

// MARK: - Wire

extension MexcFutures.PendingOrderCounts: Decodable {
    private enum CodingKeys: String, CodingKey {
        case sumCount, limitOrderCount, stopOrderCount, planOrderCount, trackOrderCount
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        total = try container.decode(Int.self, forKey: .sumCount)
        limitOrders = try container.decode(Int.self, forKey: .limitOrderCount)
        stopOrders = try container.decode(Int.self, forKey: .stopOrderCount)
        planOrders = try container.decode(Int.self, forKey: .planOrderCount)
        trailingOrders = try container.decode(Int.self, forKey: .trackOrderCount)
    }
}
