/// The live ``MexcFutures/SelfTradePreventionAPI``.
struct SelfTradePreventionEndpoints: MexcFutures.SelfTradePreventionAPI {
    let rest: RESTClient

    // MARK: - Endpoints

    func groups(_ name: String?) async throws -> [MexcFutures.SelfTradePreventionGroup] {
        try await rest.send(
            .get(
                "/api/v1/private/market_maker/self_trade/blacklist", query: ["configName": name], authentication: .signed
            ))
    }

    func currentGroup() async throws -> MexcFutures.SelfTradePreventionGroup? {
        try await rest.send(.get("/api/v1/private/market_maker/self_trade/blacklist/search", authentication: .signed))
    }

    func create(_ name: String, members: [String]) async throws {
        guard members.count >= 2 else {
            throw MexcFutures.ClientError(.invalidRequest, message: "A self-trade prevention group needs at least two members")
        }
        let body = Group(configName: name, blacklist: try members.map(Self.uid))
        let _: NoData = try await rest.send(.post("/api/v1/private/market_maker/self_trade/blacklist/create", .json(body)))
    }

    func update(_ name: String, members: [String]) async throws {
        let body = Group(configName: name, blacklist: try members.map(Self.uid))
        let _: NoData = try await rest.send(.post("/api/v1/private/market_maker/self_trade/blacklist/update", .json(body)))
    }

    func delete(_ name: String) async throws {
        let body = ["configName": name]
        let _: NoData = try await rest.send(.post("/api/v1/private/market_maker/self_trade/blacklist/delete", .json(body)))
    }

    /// A UID as the JSON number MEXC's `number[]` takes; a non-numeric one throws
    /// ``MexcFutures/ClientError/Reason/invalidRequest``.
    private static func uid(_ text: String) throws -> Int64 {
        guard let uid = Int64(text) else {
            throw MexcFutures.ClientError(.invalidRequest, message: "Not a numeric UID: \(text)")
        }
        return uid
    }
}

// MARK: - Wire

private struct Group: Encodable, Sendable {
    let configName: String
    let blacklist: [Int64]
}
