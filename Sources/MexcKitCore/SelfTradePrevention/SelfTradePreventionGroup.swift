public import Foundation

// MARK: - Model

extension MexcFutures {
    /// A self-trade prevention group: a named list of sub-accounts, which MEXC calls a blacklist group.
    public struct SelfTradePreventionGroup: Hashable, Sendable {
        /// The group's name, which also identifies it.
        public let name: String
        /// The UIDs of the group's sub-accounts.
        public let members: [String]
        public let createdAt: Date
        public let updatedAt: Date?

        public init(name: String, members: [String], createdAt: Date, updatedAt: Date?) {
            self.name = name
            self.members = members
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }
}

// MARK: - Wire

extension MexcFutures.SelfTradePreventionGroup: Decodable {
    private enum CodingKeys: String, CodingKey {
        case groupName, blackList, createTime, updateTime
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .groupName)
        // The table types the list as a string; the example sends an array of strings.
        members = try container.decode([FlexibleString].self, forKey: .blackList).map(\.value)
        createdAt = try container.millisecondDate(forKey: .createTime)
        updatedAt = try container.millisecondDateIfPresent(forKey: .updateTime)
    }
}
