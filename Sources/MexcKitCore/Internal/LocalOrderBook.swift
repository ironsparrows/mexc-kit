import Foundation

/// An order book kept from a snapshot and the changes that follow it, by MEXC's maintenance rules
/// (`websocket-api/incremental-order-book-maintenance-mechanism`): a change applies when its version
/// is one more than the book's; an older one is skipped; a newer one waits until the versions
/// between arrive. A change's volume is the level's new total, and a volume of 0 removes the level.
struct LocalOrderBook {
    private var asks: Side
    private var bids: Side
    private(set) var version: Int64
    private var time: Date
    /// Changes past a missing version, by version.
    private var waiting: [Int64: MexcFutures.OrderBook.Change] = [:]

    init(_ snapshot: MexcFutures.OrderBook) {
        asks = Side(snapshot.asks, lowestFirst: true)
        bids = Side(snapshot.bids, lowestFirst: false)
        version = snapshot.version
        time = snapshot.time
    }

    /// Whether every change received so far has been applied, with no version missing.
    var isSynchronized: Bool { waiting.isEmpty }

    /// The book, best levels first.
    var orderBook: MexcFutures.OrderBook {
        MexcFutures.OrderBook(asks: asks.levels, bids: bids.levels, version: version, time: time)
    }

    /// Replaces the book with `snapshot`, then applies the waiting changes that follow it.
    mutating func reset(to snapshot: MexcFutures.OrderBook) {
        let waiting = waiting.filter { $0.key > snapshot.version }
        self = LocalOrderBook(snapshot)
        self.waiting = waiting
        applyWaiting()
    }

    /// Applies `change` if it's the next version, and then any waiting changes that follow it.
    mutating func apply(_ change: MexcFutures.OrderBook.Change) {
        if change.version == version + 1, waiting.isEmpty {
            update(with: change)
        } else if change.version > version {
            waiting[change.version] = change
            applyWaiting()
        }
    }

    private mutating func applyWaiting() {
        while let change = waiting.removeValue(forKey: version + 1) {
            update(with: change)
        }
    }

    private mutating func update(with change: MexcFutures.OrderBook.Change) {
        for level in change.asks { asks.set(level) }
        for level in change.bids { bids.set(level) }
        version = change.version
        time = change.time ?? time
    }
}

extension LocalOrderBook {
    /// One side of the book, its levels kept best first.
    private struct Side {
        private(set) var levels: [MexcFutures.OrderBook.Level]
        /// Whether the best price is the lowest, as for asks, or the highest, as for bids.
        private let lowestFirst: Bool

        init(_ levels: [MexcFutures.OrderBook.Level], lowestFirst: Bool) {
            self.lowestFirst = lowestFirst
            self.levels = levels.sorted { Self.isBetter($0.price, than: $1.price, lowestFirst: lowestFirst) }
        }

        private func isBetter(_ price: Decimal, than other: Decimal) -> Bool {
            Self.isBetter(price, than: other, lowestFirst: lowestFirst)
        }

        private static func isBetter(_ price: Decimal, than other: Decimal, lowestFirst: Bool) -> Bool {
            lowestFirst ? price < other : price > other
        }

        /// Puts `level` in its place, replacing the level at its price; a volume of 0 removes it.
        mutating func set(_ level: MexcFutures.OrderBook.Level) {
            // The first index whose price isn't better than the level's.
            var low = 0
            var high = levels.count
            while low < high {
                let middle = (low + high) / 2
                if isBetter(levels[middle].price, than: level.price) { low = middle + 1 } else { high = middle }
            }
            let exists = low < levels.count && levels[low].price == level.price
            switch (exists, level.volume == 0) {
            case (true, true): levels.remove(at: low)
            case (true, false): levels[low] = level
            case (false, true): break
            case (false, false): levels.insert(level, at: low)
            }
        }
    }
}
