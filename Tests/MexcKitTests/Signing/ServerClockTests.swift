import Foundation
import Testing

@testable import MexcKit

extension MexcKitTests {
    @Suite("Server clock")
    struct ServerClockTests {
        @Test func `without synchronizing, MEXC's time is the local time`() async {
            let clock = ServerClock { Date(timeIntervalSince1970: 1_000) }
            #expect(await clock.now() == Date(timeIntervalSince1970: 1_000))
        }

        @Test func `the offset is measured against the middle of the request`() async throws {
            // MEXC answers 1,011 s after a 200 ms round trip that started at local 1,000 s, so MEXC is
            // 10.9 s ahead, give or take the sleep's overshoot.
            let clock = ServerClock { Date(timeIntervalSince1970: 1_000) }
            try await clock.synchronize {
                try await Task.sleep(for: .milliseconds(200))
                return Date(timeIntervalSince1970: 1_011)
            }
            let offset = await clock.now().timeIntervalSince1970 - 1_000
            #expect(offset > 10.7 && offset <= 10.9)
        }

        @Test func `the shorter of two round trips wins`() async throws {
            let delays = Delays([.milliseconds(400), .zero])
            let clock = ServerClock { Date(timeIntervalSince1970: 1_000) }
            try await clock.synchronize {
                try await Task.sleep(for: await delays.next())
                return Date(timeIntervalSince1970: 1_011)
            }
            let offset = await clock.now().timeIntervalSince1970 - 1_000
            #expect(offset > 10.9 && offset <= 11)
        }

        @Test func `the client applies the offset to the request time`() async throws {
            let clock = ServerClock { Date(timeIntervalSince1970: 1_700_000_000) }
            let ping = TransportResponse(status: 200, body: Data(#"{"success":true,"code":0,"data":1700000003000}"#.utf8))
            let transport = FakeTransport(responses: [ping, ping])
            let client = MexcFutures.Client(
                credentialsProvider: { MexcCredentials(apiKey: "k", secret: "s") }, configuration: .init(), transport: transport,
                clock: clock
            )
            try await client.synchronizeClock()
            let pingRequest = """
                GET https://api.mexc.com/api/v1/contract/ping
                Content-Type: application/json
                """
            #expect(await transport.requests.map(\.rendered) == [pingRequest, pingRequest])
            let request = try await client.rest.request(for: Endpoint<Bool>.post("/api/v1/private/position/close_all"))
            // The fake answers at once, so the offset is 3 s less at most a few milliseconds.
            let requestTime = try #require(request.headers.first { $0.name == "Request-Time" }.flatMap { Int64($0.value) })
            #expect((1_700_000_002_900...1_700_000_003_000).contains(requestTime))
        }
    }
}

/// Hands out scripted delays, one per call.
private actor Delays {
    private var delays: [Duration]

    init(_ delays: [Duration]) {
        self.delays = delays
    }

    func next() -> Duration { delays.removeFirst() }
}
