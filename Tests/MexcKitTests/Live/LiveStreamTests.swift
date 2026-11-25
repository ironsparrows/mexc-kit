import Foundation
import MexcKitTestSupport
import Testing

@testable import MexcKit

extension MexcKitTests {
    @Suite(
        "Live streams", .tags(.live), .enabled(if: areLiveTestsEnabled, "Set MEXC_API_KEY and MEXC_API_SECRET to run"),
        .timeLimit(.minutes(2))
    )
    struct LiveStreamTests {
        private static let btc: MexcFutures.Symbol = "BTC_USDT"
        private let stream = MexcFutures.Client(credentials: LiveTestSettings.credentials).stream

        @Test func `prices and the tickers decode`() async throws {
            async let ticker = Self.first(of: stream.ticker(Self.btc))
            async let summaries = Self.first(of: stream.tickers())
            async let index = Self.first(of: stream.indexPrice(Self.btc))
            async let fair = Self.first(of: stream.fairPrice(Self.btc))
            #expect(try await ticker.symbol == Self.btc)
            #expect(try await summaries.contains { $0.symbol == Self.btc })
            #expect(try await index.price > 0)
            #expect(try await fair.price > 0)
        }

        @Test func `deals and candles decode`() async throws {
            async let deals = Self.values(3, of: stream.deals(Self.btc, merged: false))
            async let candle = Self.first(of: stream.candles(Self.btc, interval: .oneMinute))
            #expect(try await deals.allSatisfy { $0.id != nil && $0.price > 0 })
            #expect(abs(try await candle.time.timeIntervalSinceNow) < 120)
        }

        @Test func `order books and their changes decode in order`() async throws {
            async let changes = Self.values(5, of: stream.orderBookChanges(Self.btc))
            async let book = Self.first(of: stream.orderBooks(Self.btc, limit: 5))
            async let grouped = Self.first(of: stream.orderBooks(Self.btc, step: 10))
            // Usually one more each; MEXC's documentation allows gaps, as packet loss, which the local order
            // book recovers from. Increasing is what every change promises.
            let versions = try await changes.map(\.version)
            #expect(zip(versions, versions.dropFirst()).allSatisfy { $1 > $0 }, "versions: \(versions)")
            #expect(try await book.asks.count == 5)
            #expect(try await grouped.bids.isEmpty == false)
        }

        private static func first<Element: Sendable>(of stream: AsyncThrowingStream<Element, any Error>) async throws -> Element {
            try #require(try await values(1, of: stream).first)
        }

        private static func values<Element: Sendable>(
            _ count: Int, of stream: AsyncThrowingStream<Element, any Error>
        ) async throws -> [Element] {
            var values: [Element] = []
            for try await value in stream {
                values.append(value)
                if values.count == count { break }
            }
            return values
        }
    }
}
