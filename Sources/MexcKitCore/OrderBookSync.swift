// MARK: - Model

extension MexcFutures {
    /// A market's order book kept up to date from its changes: each element is the book after a
    /// change.
    ///
    /// ```swift
    /// for try await book in MexcFutures.OrderBookSync("BTC_USDT", client: client) {
    ///     print(book.bids.first?.price, book.asks.first?.price)
    /// }
    /// ```
    ///
    /// Iterating subscribes to ``StreamAPI/orderBookChanges(_:)``, reads a snapshot of the top 1,000
    /// levels a side, and applies the changes that follow it by version, as MEXC's documentation
    /// describes. Deeper levels appear once a change touches them. When a version is missing, such as
    /// after a reconnect, it catches up from the last 1,000 changes, or from a new snapshot when those
    /// don't reach back far enough. While MEXC's REST data lags behind the stream it tries again on a
    /// later change, at most every half second, which keeps one book well within MEXC's rate limits
    /// for both requests. A catch-up that fails, such as one MEXC rate-limits after a reconnect, is
    /// tried again on a later change too, waiting twice as long after each failure, up to about half a
    /// minute.
    ///
    /// Elements come only while no version is missing; a consumer that falls behind gets the latest
    /// book only. The sequence ends with the error the first snapshot or the stream throws, and ends
    /// when the stream does. Each iteration keeps a book of its own.
    public struct OrderBookSync: AsyncSequence, Sendable {
        public typealias Element = OrderBook

        public let symbol: Symbol
        private let readSnapshot: @Sendable () async throws -> OrderBook
        private let readRecentChanges: @Sendable () async throws -> [OrderBook.Change]
        private let subscribe: @Sendable () -> AsyncThrowingStream<OrderBook.Change, any Error>
        /// The least time between two attempts to catch up.
        private let catchUpInterval: Duration

        /// Keeps `symbol`'s order book with `market`'s snapshots and `stream`'s changes.
        public init(_ symbol: Symbol, market: some MarketAPI, stream: some StreamAPI) {
            self.init(
                symbol,
                readSnapshot: { try await market.orderBook(symbol, limit: Self.depth) },
                readRecentChanges: { try await market.orderBookChanges(symbol, limit: Self.depth) },
                subscribe: { stream.orderBookChanges(symbol) }
            )
        }

        /// Keeps `symbol`'s order book with `client`'s market data and streams.
        public init(_ symbol: Symbol, client: some API) {
            self.init(symbol, market: client.market, stream: client.stream)
        }

        /// The seam the tests script: the reads and the subscription as closures, and the pause
        /// between catch-ups.
        package init(
            _ symbol: Symbol, readSnapshot: @escaping @Sendable () async throws -> OrderBook,
            readRecentChanges: @escaping @Sendable () async throws -> [OrderBook.Change],
            subscribe: @escaping @Sendable () -> AsyncThrowingStream<OrderBook.Change, any Error>,
            catchUpInterval: Duration = .milliseconds(500)
        ) {
            self.symbol = symbol
            self.readSnapshot = readSnapshot
            self.readRecentChanges = readRecentChanges
            self.subscribe = subscribe
            self.catchUpInterval = catchUpInterval
        }

        public func makeAsyncIterator() -> Iterator {
            let (books, continuation) = AsyncThrowingStream.makeStream(
                of: OrderBook.self, bufferingPolicy: .bufferingNewest(1)
            )
            let syncing = Task {
                do {
                    try await sync { continuation.yield($0) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in syncing.cancel() }
            return Iterator(books: books.makeAsyncIterator())
        }

        /// The levels a side of a snapshot, and the number of recent changes read to catch up: the
        /// 1,000 MEXC's documentation uses for both.
        private static let depth = 1000

        /// Keeps the book until the changes end, passing it to `publish` after each change that
        /// leaves it complete.
        private func sync(publish: (OrderBook) -> Void) async throws {
            // Subscribed before the snapshot, as Mexc.Net does. Changes the subscription misses
            // until MEXC acknowledges it are caught up like any other gap.
            let changes = subscribe()
            var book = LocalOrderBook(try await readSnapshot())
            publish(book.orderBook)
            let clock = ContinuousClock()
            var nextCatchUp = clock.now
            var failedCatchUps = 0
            for try await change in changes {
                let version = book.version
                book.apply(change)
                if !book.isSynchronized, clock.now >= nextCatchUp {
                    do {
                        try await catchUp(&book)
                        failedCatchUps = 0
                    } catch {
                        if Task.isCancelled { throw error }
                        failedCatchUps += 1
                    }
                    nextCatchUp = clock.now + catchUpInterval * (1 << Swift.min(failedCatchUps, 6))
                }
                if book.isSynchronized, book.version != version {
                    publish(book.orderBook)
                }
            }
        }

        /// Fills a missing version from the recent changes, or, when they don't reach back to the
        /// book's version, from a new snapshot that is newer than the book. When neither helps,
        /// MEXC's REST data lags behind the stream, and a later change tries again.
        private func catchUp(_ book: inout LocalOrderBook) async throws {
            let recentChanges = try await readRecentChanges()
            // Their order doesn't matter: each waits for the version before it.
            for change in recentChanges {
                book.apply(change)
            }
            guard !book.isSynchronized,
                (recentChanges.map(\.version).min() ?? .max) > book.version + 1
            else { return }
            let snapshot = try await readSnapshot()
            if snapshot.version > book.version {
                book.reset(to: snapshot)
            }
        }
    }
}

// MARK: - Iterator

extension MexcFutures.OrderBookSync {
    /// Iterates the books of one sync; ending the iteration ends the sync and its subscription.
    public struct Iterator: AsyncIteratorProtocol {
        fileprivate var books: AsyncThrowingStream<MexcFutures.OrderBook, any Error>.Iterator

        /// The next book, waited for on the caller's isolation.
        @available(macOS 15, iOS 18, tvOS 18, visionOS 2, *)
        public mutating func next(
            isolation actor: isolated (any Actor)? = #isolation
        ) async throws(any Error) -> MexcFutures.OrderBook? {
            try await books.next(isolation: actor)
        }

        /// The next book. Before the OS versions with `next(isolation:)`, it is waited for off the
        /// caller's isolation, as the underlying stream's own `next()` is.
        @concurrent public mutating func next() async throws -> MexcFutures.OrderBook? {
            try await books.next()
        }
    }
}
