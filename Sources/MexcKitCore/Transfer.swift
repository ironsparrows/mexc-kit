public import Foundation

// MARK: - Model

extension MexcFutures {
    /// A transfer of an asset into or out of the futures account.
    ///
    /// The optional properties are in MEXC's documentation but not yet in a recorded response; `nil`
    /// means the response didn't include the field.
    public struct Transfer: Hashable, Sendable {
        /// MEXC's ID for the transfer.
        public let id: String
        /// MEXC's transaction ID.
        public let transactionID: String?
        public let asset: String
        public let amount: Decimal
        public let direction: TransferDirection
        public let state: TransferState
        public let createdAt: Date
        public let updatedAt: Date?

        public init(
            id: String, transactionID: String?, asset: String, amount: Decimal, direction: TransferDirection,
            state: TransferState, createdAt: Date, updatedAt: Date?
        ) {
            self.id = id
            self.transactionID = transactionID
            self.asset = asset
            self.amount = amount
            self.direction = direction
            self.state = state
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }
}

// MARK: - Wire

extension MexcFutures.Transfer: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, txid, currency, amount, type, state, createTime, updateTime
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(FlexibleString.self, forKey: .id).value
        transactionID = try container.decodeIfPresent(String.self, forKey: .txid)
        asset = try container.decode(String.self, forKey: .currency)
        amount = try container.decimal(forKey: .amount)
        direction = try container.decode(MexcFutures.TransferDirection.self, forKey: .type)
        state = try container.decode(MexcFutures.TransferState.self, forKey: .state)
        createdAt = try container.millisecondDate(forKey: .createTime)
        updatedAt = try container.millisecondDateIfPresent(forKey: .updateTime)
    }
}
