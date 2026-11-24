import Foundation
import MexcKit
import MexcKitTestSupport
import Testing

// Keeps BTC_USDT's order book for a few changes and checks every book is sorted and never crossed.
@Suite(
    "Live order book sync", .tags(.live),
    .enabled(if: areLiveTestsEnabled, "Set MEXC_API_KEY and MEXC_API_SECRET to run"), .timeLimit(.minutes(2))
)
struct LiveOrderBookSyncTests {
    private let client = MexcFutures.Client(credentials: LiveTestSettings.credentials)

    @Test func `BTC_USDT's book stays sorted and uncrossed over a few changes`() async throws {
        var books: [MexcFutures.OrderBook] = []
        for try await book in MexcFutures.OrderBookSync("BTC_USDT", client: client) {
            books.append(book)
            if books.count == 10 { break }
        }

        #expect(zip(books, books.dropFirst()).allSatisfy { $0.version < $1.version })
        for book in books {
            let bestBid = try #require(book.bids.first?.price)
            let bestAsk = try #require(book.asks.first?.price)
            #expect(bestBid < bestAsk)
            #expect(zip(book.asks, book.asks.dropFirst()).allSatisfy { $0.price < $1.price })
            #expect(zip(book.bids, book.bids.dropFirst()).allSatisfy { $0.price > $1.price })
        }
    }
}
