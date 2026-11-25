import Foundation
import Testing
@testable import MexcKit

// Private responses can't be recorded without the user's key, so the group list runs against the example
// in MEXC's documentation (whitespace aside). The current group's documented example has no `data`; the
// tests cover that and a group built from the list's fields. Each test pins the exact request.
@Suite("Self-trade prevention endpoints")
struct SelfTradePreventionEndpointsTests {
    private static let accepted = #"{"success":true,"code":0}"#

    @Test func `the groups`() async throws {
        let transport = try FakeTransport(fixture: "SelfTradePrevention/blacklist")
        let groups = try await SelfTradePreventionEndpoints(rest: .test(transport: transport)).groups("stpconfi001")
        #expect(await transport.requests.first?.url.absoluteString == """
            https://api.mexc.com/api/v1/private/market_maker/self_trade/blacklist?configName=stpconfi001
            """)
        #expect(groups == [.init(
            name: "stpconfi001", members: ["45359845", "72009483"],
            createdAt: Date(timeIntervalSince1970: 1_768_804_555), updatedAt: Date(timeIntervalSince1970: 1_768_804_555)
        )])
    }

    @Test func `every group`() async throws {
        let transport = FakeTransport(json: #"{"success":true,"code":0,"data":[]}"#)
        #expect(try await SelfTradePreventionEndpoints(rest: .test(transport: transport)).groups().isEmpty)
        #expect(await transport.requests.first?.url.absoluteString == """
            https://api.mexc.com/api/v1/private/market_maker/self_trade/blacklist
            """)
    }

    @Test(arguments: [
        (Self.accepted, nil),
        (#"{"success":true,"code":0,"data":null}"#, nil),
        (#"{"success":true,"code":0,"data":{"groupName":"g1","blackList":[1,"2"],"createTime":1}}"#, "g1"),
    ])
    func `the current group, which may be missing`(json: String, name: String?) async throws {
        let transport = FakeTransport(json: json)
        let group = try await SelfTradePreventionEndpoints(rest: .test(transport: transport)).currentGroup()
        #expect(group?.name == name)
        #expect(await transport.requests.first?.url.absoluteString == """
            https://api.mexc.com/api/v1/private/market_maker/self_trade/blacklist/search
            """)
    }

    @Test func `creating, updating and deleting a group`() async throws {
        let transport = FakeTransport(responses: Array(repeating: .init(status: 200, body: Data(Self.accepted.utf8)), count: 3))
        let endpoints = SelfTradePreventionEndpoints(rest: .test(transport: transport))
        try await endpoints.create("g1", members: ["45359845", "72009483"])
        try await endpoints.update("g1", members: ["45359845"])
        try await endpoints.delete("g1")
        let sent = await transport.requests
        #expect(sent.map(\.url.absoluteString) == [
            "https://api.mexc.com/api/v1/private/market_maker/self_trade/blacklist/create",
            "https://api.mexc.com/api/v1/private/market_maker/self_trade/blacklist/update",
            "https://api.mexc.com/api/v1/private/market_maker/self_trade/blacklist/delete",
        ])
        #expect(sent.map(\.bodyText) == [
            #"{"blacklist":[45359845,72009483],"configName":"g1"}"#,
            #"{"blacklist":[45359845],"configName":"g1"}"#,
            #"{"configName":"g1"}"#,
        ])
        #expect(sent.allSatisfy { $0.method == .post && $0.headers.contains { $0.name == "Signature" } })
    }

    @Test(arguments: [["45359845"], ["45359845", "sub-two"]])
    func `a group with fewer than two members or a non-numeric UID throws before sending`(members: [String]) async throws {
        let transport = FakeTransport()
        let error = try await #require(throws: MexcFutures.ClientError.self) {
            try await SelfTradePreventionEndpoints(rest: .test(transport: transport)).create("g1", members: members)
        }
        #expect(error.reason == .invalidRequest)
        #expect(await transport.requests.isEmpty)
    }
}
