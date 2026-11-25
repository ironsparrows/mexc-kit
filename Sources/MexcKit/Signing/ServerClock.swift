import Foundation

/// MEXC's clock as this device sees it: the local clock plus a measured offset.
///
/// MEXC rejects a signed request whose `Request-Time` is too far from its own clock, so a device
/// whose clock drifts can measure the offset once with ``synchronize(fetchingServerTime:)``.
actor ServerClock {
    private let localNow: @Sendable () -> Date
    private var offset: TimeInterval = 0

    init(localNow: @escaping @Sendable () -> Date = { Date() }) {
        self.localNow = localNow
    }

    func now() -> Date { localNow().addingTimeInterval(offset) }

    /// Sets the offset to the server time minus the local time halfway through the request.
    ///
    /// Asks twice and keeps the measurement with the shorter round trip, so the time spent opening
    /// the connection on the first request doesn't skew it. Round trips are timed with a monotonic
    /// clock, so a change to the device's clock during the measurement doesn't either.
    func synchronize(fetchingServerTime: @Sendable () async throws -> Date) async throws {
        var best: (offset: TimeInterval, roundTrip: Duration)?
        for _ in 1...2 {
            let sent = localNow()
            let start = ContinuousClock.now
            let serverTime = try await fetchingServerTime()
            let roundTrip = start.duration(to: .now)
            if let best, best.roundTrip <= roundTrip { continue }
            best = (serverTime.timeIntervalSince(sent) - roundTrip.seconds / 2, roundTrip)
        }
        offset = best?.offset ?? offset
    }
}

extension Endpoint<MillisecondTimestamp> {
    /// `GET /api/v1/contract/ping`: MEXC's current time.
    static var serverTime: Self { .get("/api/v1/contract/ping") }
}

extension Duration {
    fileprivate var seconds: TimeInterval {
        let (seconds, attoseconds) = components
        return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
    }
}
