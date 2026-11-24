import Foundation
import Testing
@testable import MexcKit

@Suite("Live REST", .tags(.live), .liveServersEnabled)
struct LiveRESTTests {
    @Test func `the clock synchronizes with MEXC`() async throws {
        let client = MexcFutures.Client()
        try await client.synchronizeClock()
        // A wrong unit (seconds for milliseconds) would put MEXC's clock decades away.
        #expect(abs(await client.clock.now().timeIntervalSinceNow) < 60)
    }
}
