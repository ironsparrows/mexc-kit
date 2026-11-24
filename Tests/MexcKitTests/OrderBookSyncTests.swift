import Foundation
import Testing
@testable import MexcKit

/// The order book kept from a snapshot and its changes: scripted sequences for each path of MEXC's
/// maintenance rules, and one recorded snapshot with the recorded changes that follow it.
@Suite("Order book sync", .timeLimit(.minutes(1)))
struct OrderBookSyncTests {
    private let script = Script()
    private let changes: AsyncThrowingStream<MexcFutures.OrderBook.Change, any Error>
    /// What MEXC's stream pushes, in order.
    private let pushes: AsyncThrowingStream<MexcFutures.OrderBook.Change, any Error>.Continuation

    init() {
        (changes, pushes) = AsyncThrowingStream.makeStream(of: MexcFutures.OrderBook.Change.self)
    }

    // MARK: In order

    @Test func `the snapshot comes first, then the book after each change in order`() async throws {
        await script.snapshots([Self.book(version: 10, asks: [(102, 7), (101, 5)], bids: [(98, 4), (99, 3)])])
        var books = sync().makeAsyncIterator()
        let snapshot = try #require(try await books.next())
        #expect(snapshot.version == 10)
        #expect(snapshot.asks.map(\.price) == [101, 102])
        #expect(snapshot.bids.map(\.price) == [99, 98])

        pushes.yield(Self.change(11, asks: [(101, 0), (103, 1), (104, 0)], bids: [(100, 2), (99, 6)]))
        let book = try #require(try await books.next())
        #expect(book.version == 11)
        #expect(book.asks.map(\.price) == [102, 103])
        #expect(book.bids.map(\.price) == [100, 99, 98])
        #expect(book.bids.map(\.volume) == [2, 6, 4])
        #expect(book.time == Date(timeIntervalSince1970: 11))
    }

    @Test func `changes older than the snapshot are skipped`() async throws {
        await script.snapshots([Self.book(version: 10)])
        pushes.yield(Self.change(9, bids: [(50, 1)]))
        pushes.yield(Self.change(10, bids: [(51, 1)]))
        pushes.yield(Self.change(11, bids: [(52, 1)]))
        var books = sync().makeAsyncIterator()

        var book = try #require(try await books.next())
        while book.version < 11 {
            book = try #require(try await books.next())
        }
        #expect(book.bids.map(\.price) == [99, 52])
        #expect(await script.recentChangesReads == 0)
    }

    @Test func `a change without a time keeps the book's time`() async throws {
        await script.snapshots([Self.book(version: 10)])
        var books = sync().makeAsyncIterator()
        _ = try await books.next()

        pushes.yield(MexcFutures.OrderBook.Change(asks: [], bids: [], version: 11))
        #expect(try await books.next()?.time == Date(timeIntervalSince1970: 10))
    }

    // MARK: Gaps

    @Test func `a gap is filled from the recent changes`() async throws {
        await script.snapshots([Self.book(version: 10)])
        await script.recentChanges([[Self.change(13, asks: [(104, 1)]), Self.change(12), Self.change(11, asks: [(103, 2)])]])
        var books = sync().makeAsyncIterator()
        _ = try await books.next()

        pushes.yield(Self.change(13, asks: [(104, 1)]))
        let book = try #require(try await books.next())
        #expect(book.version == 13)
        #expect(book.asks.map(\.price) == [101, 103, 104])
        #expect(await script.snapshotReads == 1)
    }

    @Test func `a gap the recent changes don't reach is filled from a new snapshot`() async throws {
        await script.snapshots([Self.book(version: 10), Self.book(version: 15, asks: [(105, 1)])])
        await script.recentChanges([[Self.change(14), Self.change(15)]])
        var books = sync().makeAsyncIterator()
        _ = try await books.next()

        pushes.yield(Self.change(16, asks: [(106, 1)]))
        let book = try #require(try await books.next())
        #expect(book.version == 16)
        #expect(book.asks.map(\.price) == [105, 106])
        #expect(await script.snapshotReads == 2)
    }

    @Test func `a new snapshot older than the book is ignored`() async throws {
        await script.snapshots([Self.book(version: 10), Self.book(version: 8, asks: [(108, 1)])])
        await script.recentChanges([[Self.change(14)], [Self.change(11), Self.change(12), Self.change(13)]])
        var books = sync().makeAsyncIterator()
        _ = try await books.next()

        pushes.yield(Self.change(15))
        pushes.yield(Self.change(16))
        let book = try #require(try await books.next())
        #expect(book.version == 16)
        #expect(book.asks.map(\.price) == [101])
    }

    @Test func `while MEXC's REST data lags, the next change tries again without a snapshot`() async throws {
        // The first catch-up gets only changes the book already has, so no book is published until
        // the next one gets the missing ones.
        await script.snapshots([Self.book(version: 10)])
        await script.recentChanges([[Self.change(9), Self.change(10)], [Self.change(11), Self.change(12), Self.change(13)]])
        var books = sync().makeAsyncIterator()
        _ = try await books.next()

        pushes.yield(Self.change(12))
        pushes.yield(Self.change(13, bids: [(100, 1)]))
        let book = try #require(try await books.next())
        #expect(book.version == 13)
        #expect(book.bids.first?.price == 100)
        #expect(await script.recentChangesReads == 2)
        #expect(await script.snapshotReads == 1)
    }

    @Test func `catching up waits the interval between attempts`() async throws {
        await script.snapshots([Self.book(version: 10)])
        await script.recentChanges([[Self.change(10)]])
        var books = sync(catchUpInterval: .seconds(60)).makeAsyncIterator()
        _ = try await books.next()

        for version: Int64 in 12...20 {
            pushes.yield(Self.change(version))
        }
        // Change 11 arrives late, which ends the gap without another request.
        pushes.yield(Self.change(11))
        var book = try #require(try await books.next())
        while book.version < 20 {
            book = try #require(try await books.next())
        }
        #expect(await script.recentChangesReads == 1)
    }

    // MARK: Ending

    @Test func `a failing snapshot ends the sequence with its error`() async throws {
        var books = sync().makeAsyncIterator()
        await #expect(throws: MexcError.self) { try await books.next() }
    }

    @Test func `a failing stream ends the sequence with its error`() async throws {
        await script.snapshots([Self.book(version: 10)])
        var books = sync().makeAsyncIterator()
        _ = try await books.next()

        pushes.finish(throwing: MexcFutures.ClientError(.connectionFailed))
        let error = try await #require(throws: MexcFutures.ClientError.self) { try await books.next() }
        #expect(error.reason == .connectionFailed)
    }

    @Test func `the sequence ends when the changes end`() async throws {
        await script.snapshots([Self.book(version: 10)])
        var books = sync().makeAsyncIterator()
        _ = try await books.next()

        pushes.finish()
        #expect(try await books.next() == nil)
    }

    @Test func `releasing the iterator ends the changes`() async throws {
        await script.snapshots([Self.book(version: 10)])
        let ended = Ended()
        pushes.onTermination = { _ in Task { await ended.set() } }
        var books: MexcFutures.OrderBookSync.Iterator? = sync().makeAsyncIterator()
        _ = try await books?.next()

        books = nil
        await ended.wait()
    }

    @Test func `cancelling the iterating task ends the changes`() async throws {
        await script.snapshots([Self.book(version: 10)])
        let ended = Ended()
        pushes.onTermination = { _ in Task { await ended.set() } }
        let sync = sync()
        let iterating = Task {
            for try await _ in sync {}
        }

        iterating.cancel()
        await ended.wait()
    }

    // MARK: Recorded

    @Test func `a recorded snapshot catches up with the recorded changes after it`() async throws {
        let transport = try FakeTransport(fixtures: ["Market/depth", "Market/depth_commits"])
        let market = MarketEndpoints(rest: .test(transport: transport))
        let changes = changes
        let sync = MexcFutures.OrderBookSync(
            "BTC_USDT", readSnapshot: { try await market.orderBook("BTC_USDT", limit: 1000) },
            readRecentChanges: { try await market.orderBookChanges("BTC_USDT", limit: 1000) },
            subscribe: { changes }
        )
        var books = sync.makeAsyncIterator()
        let snapshot = try #require(try await books.next())
        #expect(snapshot.version == 43_833_673_146)

        // The last recorded change arrives first, so the two before it are missing.
        pushes.yield(MexcFutures.OrderBook.Change(
            asks: [], bids: [MexcFutures.OrderBook.Level(price: Decimal(string: "60007.7")!, volume: 206_189, orderCount: 2)],
            version: 43_833_673_149
        ))
        let book = try #require(try await books.next())
        #expect(book.version == 43_833_673_149)
        #expect(book.asks.first { $0.price == Decimal(string: "60007.8")! }?.volume == 393_945)
        #expect(book.bids.first { $0.price == Decimal(string: "60007.7")! }?.volume == 206_189)
        #expect(zip(book.asks, book.asks.dropFirst()).allSatisfy { $0.price < $1.price })
        #expect(zip(book.bids, book.bids.dropFirst()).allSatisfy { $0.price > $1.price })
        #expect(await transport.requests.map(\.url.absoluteString) == [
            "https://api.mexc.com/api/v1/contract/depth/BTC_USDT?limit=1000",
            "https://api.mexc.com/api/v1/contract/depth_commits/BTC_USDT/1000",
        ])
    }

    // MARK: Helpers

    private func sync(catchUpInterval: Duration = .zero) -> MexcFutures.OrderBookSync {
        let script = script
        let changes = changes
        return MexcFutures.OrderBookSync(
            "BTC_USDT", readSnapshot: { try await script.nextSnapshot() },
            readRecentChanges: { try await script.nextRecentChanges() }, subscribe: { changes },
            catchUpInterval: catchUpInterval
        )
    }

    /// A book with the given levels, and by default one ask at 101 and one bid at 99.
    private static func book(
        version: Int64, asks: [(Decimal, Decimal)] = [(101, 1)], bids: [(Decimal, Decimal)] = [(99, 1)]
    ) -> MexcFutures.OrderBook {
        MexcFutures.OrderBook(
            asks: levels(asks), bids: levels(bids), version: version, time: Date(timeIntervalSince1970: TimeInterval(version))
        )
    }

    private static func change(
        _ version: Int64, asks: [(Decimal, Decimal)] = [], bids: [(Decimal, Decimal)] = []
    ) -> MexcFutures.OrderBook.Change {
        MexcFutures.OrderBook.Change(
            asks: levels(asks), bids: levels(bids), version: version, time: Date(timeIntervalSince1970: TimeInterval(version))
        )
    }

    private static func levels(_ levels: [(Decimal, Decimal)]) -> [MexcFutures.OrderBook.Level] {
        levels.map { MexcFutures.OrderBook.Level(price: $0, volume: $1, orderCount: 1) }
    }

    /// The snapshots and recent changes MEXC answers with, in order; a read past the last throws.
    private actor Script {
        private var snapshotQueue: [MexcFutures.OrderBook] = []
        private var recentChangesQueue: [[MexcFutures.OrderBook.Change]] = []
        private(set) var snapshotReads = 0
        private(set) var recentChangesReads = 0

        func snapshots(_ books: [MexcFutures.OrderBook]) { snapshotQueue = books }
        func recentChanges(_ lists: [[MexcFutures.OrderBook.Change]]) { recentChangesQueue = lists }

        func nextSnapshot() throws -> MexcFutures.OrderBook {
            snapshotReads += 1
            guard !snapshotQueue.isEmpty else { throw MexcError(code: .busy, message: "No snapshot scripted") }
            return snapshotQueue.removeFirst()
        }

        func nextRecentChanges() throws -> [MexcFutures.OrderBook.Change] {
            recentChangesReads += 1
            guard !recentChangesQueue.isEmpty else { throw MexcError(code: .busy, message: "No changes scripted") }
            return recentChangesQueue.removeFirst()
        }
    }

    private actor Ended {
        private var isSet = false
        private var waiter: CheckedContinuation<Void, Never>?

        func set() {
            isSet = true
            waiter?.resume()
            waiter = nil
        }

        func wait() async {
            guard !isSet else { return }
            await withCheckedContinuation { waiter = $0 }
        }
    }
}
