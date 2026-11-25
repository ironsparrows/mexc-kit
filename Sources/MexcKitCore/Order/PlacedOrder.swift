public import Foundation

// MARK: - Model

extension MexcFutures {
    /// An order MEXC accepted.
    public struct PlacedOrder: Hashable, Sendable {
        public let id: OrderID
        /// When MEXC answered, by its clock.
        public let acceptedAt: Date

        public init(id: OrderID, acceptedAt: Date) {
            self.id = id
            self.acceptedAt = acceptedAt
        }
    }
}

// MARK: - Wire

extension MexcFutures.PlacedOrder: Decodable {
    private enum CodingKeys: String, CodingKey {
        case orderId, ts
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(MexcFutures.OrderID.self, forKey: .orderId)
        acceptedAt = try container.millisecondDate(forKey: .ts)
    }
}
