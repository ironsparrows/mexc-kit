// MARK: - Protocol

extension MexcFutures {
    /// Self-trade prevention groups. MEXC offers them to market maker accounts only, and answers other
    /// accounts with ``MexcError/Code/noPermission``.
    ///
    /// Reading needs credentials with MEXC's "View Order Details" permission; creating, changing and
    /// deleting need "Order Placing". A request MEXC can't take as built throws
    /// ``ClientError/Reason/invalidRequest`` before anything is sent.
    public protocol SelfTradePreventionAPI: Sendable {
        /// The groups, or only the one with this name.
        func groups(_ name: String?) async throws -> [SelfTradePreventionGroup]

        /// The group the account belongs to; `nil` when MEXC reports none. MEXC documents no response
        /// for this request; it's read as one group, as in ``groups(_:)``.
        func currentGroup() async throws -> SelfTradePreventionGroup?

        /// Creates a group of at least two sub-accounts, by their numeric UIDs.
        func create(_ name: String, members: [String]) async throws

        /// Updates a group's list of sub-accounts, by their numeric UIDs.
        func update(_ name: String, members: [String]) async throws

        /// Deletes a group.
        func delete(_ name: String) async throws
    }
}

// MARK: - Defaults

extension MexcFutures.SelfTradePreventionAPI {
    /// Every group.
    public func groups() async throws -> [MexcFutures.SelfTradePreventionGroup] {
        try await groups(nil)
    }
}
