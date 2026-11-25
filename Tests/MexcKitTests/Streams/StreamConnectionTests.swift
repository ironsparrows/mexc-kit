import Foundation
import MexcKitProtobuf
import SwiftProtobuf
import Testing

@testable import MexcKit

extension MexcKitTests {
    /// The shared connection over a fake server: subscriptions shared per route, one request at a
    /// time, routing, failures, pings and reconnecting.
    @Suite("Stream connection", .timeLimit(.minutes(1)))
    struct StreamConnectionTests {
        private let server = FakeWebSocketServer()
        private static let ticker = StreamSubscription(name: "BTC_USDT tickers", channel: "ticker", symbol: "BTC_USDT")
        private static let indexPrice = StreamSubscription(
            name: "BTC_USDT index prices", channel: "index.price", symbol: "BTC_USDT"
        )

        // MARK: Sharing and ending

        @Test func `two consumers of one route share a subscription, and the last one's end closes the connection`() async throws {
            let connection = makeConnection()
            let first = Recorder()
            let second = Recorder()
            var closes = server.closes.makeAsyncIterator()
            await connection.subscribe(Self.ticker, id: first.id, consumer: first.consumer)
            await connection.subscribe(Self.ticker, id: second.id, consumer: second.consumer)
            #expect(await server.nextSent() == Self.ticker.subscribeRequest)
            await server.acknowledge("ticker")
            try await server.push("push.ticker.BTC_USDT")

            #expect(await first.nextPush()?.symbol == "BTC_USDT")
            #expect(await second.nextPush()?.symbol == "BTC_USDT")
            await connection.unsubscribe(id: first.id, from: Self.ticker.route)
            await connection.unsubscribe(id: second.id, from: Self.ticker.route)
            await closes.next()
            // Closing the connection ends every subscription, so no unsubscribe is sent.
            #expect(await server.sentCount == 1)
        }

        @Test func `a route's last stream ending unsubscribes while other routes stay open`() async throws {
            let streams = Streams.test(server)
            let prices = streams.indexPrice("BTC_USDT")
            var ticker: AsyncThrowingStream<MexcFutures.Ticker, any Error>? = streams.ticker("BTC_USDT")
            try await acknowledge(2)

            ticker = nil
            #expect(await server.nextSent() == #"{"method":"unsub.ticker","param":{"symbol":"BTC_USDT"}}"#)
            #expect(await server.isConnected)
            withExtendedLifetime((prices, ticker)) {}
        }

        @Test func `a route whose consumers end while its request is in flight is unsubscribed once acknowledged`() async throws {
            let connection = makeConnection()
            let open = Recorder()
            let leaving = Recorder()
            await connection.subscribe(Self.ticker, id: open.id, consumer: open.consumer)
            try await acknowledge(1)
            await connection.subscribe(Self.indexPrice, id: leaving.id, consumer: leaving.consumer)
            #expect(await server.nextSent() == Self.indexPrice.subscribeRequest)

            await connection.unsubscribe(id: leaving.id, from: Self.indexPrice.route)
            await server.acknowledge("index.price")
            #expect(await server.nextSent() == Self.indexPrice.unsubscribeRequest)
        }

        @Test func `a route subscribed again with other parameters while its old request is in flight gets its own request`() async throws {
            let connection = makeConnection()
            let open = Recorder()
            let tenths = Recorder()
            let hundredths = Recorder()
            let byTenths = Self.step("0.1")
            let byHundredths = Self.step("0.01")
            await connection.subscribe(Self.ticker, id: open.id, consumer: open.consumer)
            try await acknowledge(1)
            await connection.subscribe(byTenths, id: tenths.id, consumer: tenths.consumer)
            #expect(await server.nextSent() == byTenths.subscribeRequest)

            await connection.unsubscribe(id: tenths.id, from: byTenths.route)
            await connection.subscribe(byHundredths, id: hundredths.id, consumer: hundredths.consumer)
            await server.acknowledge("depth.step")
            #expect(await server.nextSent() == byTenths.unsubscribeRequest)
            #expect(await server.nextSent() == byHundredths.subscribeRequest)
        }

        // MARK: Requests

        @Test func `a request waits for the previous one's acknowledgement`() async throws {
            let streams = Streams.test(server)
            let ticker = streams.ticker("BTC_USDT")
            let prices = streams.fairPrice("BTC_USDT")
            let firstRequest = await server.nextSent()
            try await Task.sleep(for: .milliseconds(50))
            #expect(await server.sentCount == 1)

            await server.acknowledge(try Self.channel(of: firstRequest))
            let secondRequest = await server.nextSent()
            #expect(
                Set([firstRequest, secondRequest]) == [
                    Self.ticker.subscribeRequest, #"{"method":"sub.fair.price","param":{"symbol":"BTC_USDT"}}"#,
                ])
            withExtendedLifetime((ticker, prices)) {}
        }

        @Test func `an acknowledgement that arrives while the request is still being sent counts`() async throws {
            await server.acknowledgeAtOnce()
            let streams = Streams.test(server)
            let tickers = Task { try await Self.take(1, from: streams.ticker("BTC_USDT")) }
            _ = await server.nextSent()
            try await server.push("push.ticker.BTC_USDT")

            #expect(try await tickers.value.count == 1)
        }

        @Test func `candles of two intervals on one market go to their own streams`() async throws {
            let streams = Streams.test(server)
            let fiveMinutes = Task { try await Self.take(1, from: streams.candles("BTC_USDT", interval: .fiveMinutes)) }
            let oneMinute = Task { try await Self.take(1, from: streams.candles("BTC_USDT", interval: .oneMinute)) }
            try await acknowledge(2)
            try await server.push("push.kline.BTC_USDT")

            #expect(try await oneMinute.value.map(\.time) == [Date(timeIntervalSince1970: 1_795_506_120)])
            try await Task.sleep(for: .milliseconds(50))
            fiveMinutes.cancel()
            #expect(try await fiveMinutes.value.isEmpty)
        }

        // MARK: Failures

        @Test func `a rejected subscription throws subscriptionRejected with MEXC's message`() async throws {
            let streams = Streams.test(server)
            let ticker = Task { try await Self.take(1, from: streams.ticker("NOPE_USDT")) }
            _ = await server.nextSent()
            await server.send(#"{"channel":"rs.error","data":"Contract [NOPE_USDT] not exists","ts":1}"#)

            let error = try await #require(throws: MexcFutures.ClientError.self) { try await ticker.value }
            #expect(error.reason == .subscriptionRejected)
            #expect(error.message == "Contract [NOPE_USDT] not exists")
        }

        @Test func `an unacknowledged subscription throws acknowledgementTimedOut, and the connection starts over`() async throws {
            let streams = Streams.test(server)
            let tickers = Task { try await Self.take(1, from: streams.ticker("BTC_USDT")) }
            try await acknowledge(1)
            let prices = Task { try await Self.take(1, from: streams.indexPrice("BTC_USDT")) }

            let error = try await #require(throws: MexcFutures.ClientError.self) { try await prices.value }
            #expect(error.reason == .acknowledgementTimedOut)
            #expect(error.message == "BTC_USDT index prices")
            #expect(await server.nextSent() == Self.indexPrice.subscribeRequest)
            // The ticker MEXC had acknowledged subscribes again on a new connection, and goes on.
            #expect(await server.nextSent() == Self.ticker.subscribeRequest)
            await server.acknowledge("ticker")
            try await server.push("push.ticker.BTC_USDT")
            #expect(try await tickers.value.count == 1)
            #expect(await server.connectionCount == 2)
        }

        @Test func `an acknowledgement that isn't success rejects the subscription`() async throws {
            let streams = Streams.test(server)
            let tickers = Task { try await Self.take(1, from: streams.ticker("BTC_USDT")) }
            _ = await server.nextSent()
            await server.send(#"{"channel":"rs.sub.ticker","data":"failed","ts":1}"#)

            let error = try await #require(throws: MexcFutures.ClientError.self) { try await tickers.value }
            #expect(error.reason == .subscriptionRejected)
            #expect(error.message == "failed")
        }

        @Test func `pushes before MEXC acknowledges a subscription are dropped`() async throws {
            // Such as those of the parameters a route unsubscribed just before.
            let connection = makeConnection()
            let recorder = Recorder()
            await connection.subscribe(Self.ticker, id: recorder.id, consumer: recorder.consumer)
            _ = await server.nextSent()
            await server.send(.binary(try Self.tickerPush(time: 1)))
            await server.acknowledge("ticker")
            await server.send(.binary(try Self.tickerPush(time: 2)))

            #expect(await recorder.nextPush()?.ts == 2)
        }

        @Test func `order books grouped by another step on an open market throw invalidRequest naming both`() async throws {
            let streams = Streams.test(server)
            let tenths = streams.orderBooks("DOGE_USDT", step: Decimal(string: "0.1")!)
            _ = await server.nextSent()
            let hundredths = Task { try await Self.take(1, from: streams.orderBooks("DOGE_USDT", step: Decimal(string: "0.01")!)) }

            let error = try await #require(throws: MexcFutures.ClientError.self) { try await hundredths.value }
            #expect(error.reason == .invalidRequest)
            #expect(
                error.message
                    == "DOGE_USDT order books grouped by step 0.1 are open, so DOGE_USDT order books grouped by step 0.01 can't be streamed at the same time"
            )
            withExtendedLifetime(tenths) {}
        }

        @Test func `unmerged deals while merged ones are open throw invalidRequest`() async throws {
            let streams = Streams.test(server)
            let merged = streams.deals("ETH_USDT", merged: true)
            _ = await server.nextSent()
            let unmerged = Task { try await Self.take(1, from: streams.deals("ETH_USDT", merged: false)) }

            let error = try await #require(throws: MexcFutures.ClientError.self) { try await unmerged.value }
            #expect(error.reason == .invalidRequest)
            #expect(error.message == "ETH_USDT merged deals are open, so ETH_USDT unmerged deals can't be streamed at the same time")
            withExtendedLifetime(merged) {}
        }

        @Test func `a failed first connection throws connectionFailed`() async throws {
            await server.failConnections(1)
            let streams = Streams.test(server)
            let ticker = Task { try await Self.take(1, from: streams.ticker("BTC_USDT")) }

            let error = try await #require(throws: MexcFutures.ClientError.self) { try await ticker.value }
            #expect(error.reason == .connectionFailed)
        }

        // MARK: Reconnecting

        @Test func `after a drop the connection reconnects and subscribes again to every route`() async throws {
            let streams = Streams.test(server)
            let tickers = Task { try await Self.take(2, from: streams.ticker("BTC_USDT")) }
            let prices = Task { try await Self.take(2, from: streams.indexPrice("BTC_USDT")) }
            try await acknowledge(2)
            try await server.push("push.ticker.BTC_USDT")
            try await server.push("push.index.price.BTC_USDT")

            await server.failConnections(2)
            await server.drop()
            let resubscribed = try await acknowledge(2)
            #expect(Set(resubscribed) == [Self.ticker.subscribeRequest, Self.indexPrice.subscribeRequest])
            try await server.push("push.ticker.BTC_USDT")
            try await server.push("push.index.price.BTC_USDT")

            #expect(try await tickers.value.count == 2)
            #expect(try await prices.value.count == 2)
            #expect(await server.connectAttempts == 4)
        }

        @Test func `a drop while a request waits for its acknowledgement sends it again`() async throws {
            let streams = Streams.test(server)
            let tickers = Task { try await Self.take(1, from: streams.ticker("BTC_USDT")) }
            #expect(await server.nextSent() == Self.ticker.subscribeRequest)

            await server.drop()
            #expect(await server.nextSent() == Self.ticker.subscribeRequest)
            await server.acknowledge("ticker")
            try await server.push("push.ticker.BTC_USDT")
            #expect(try await tickers.value.count == 1)
        }

        @Test func `a drop right after an acknowledgement still subscribes again`() async throws {
            let streams = Streams.test(server)
            let tickers = Task { try await Self.take(1, from: streams.ticker("BTC_USDT")) }
            #expect(await server.nextSent() == Self.ticker.subscribeRequest)

            await server.acknowledge("ticker")
            await server.drop()
            #expect(await server.nextSent() == Self.ticker.subscribeRequest)
            await server.acknowledge("ticker")
            try await server.push("push.ticker.BTC_USDT")
            #expect(try await tickers.value.count == 1)
        }

        @Test func `a stream started while reconnecting fails when connecting fails, and acknowledged ones wait`() async throws {
            let streams = Streams.test(server)
            let tickers = Task { try await Self.take(1, from: streams.ticker("BTC_USDT")) }
            try await acknowledge(1)

            // Every attempt fails until the new stream has failed.
            await server.failConnections(.max)
            await server.drop()
            let prices = Task { try await Self.take(1, from: streams.indexPrice("BTC_USDT")) }
            let error = try await #require(throws: MexcFutures.ClientError.self) { try await prices.value }
            #expect(error.reason == .connectionFailed)
            await server.failConnections(0)

            #expect(await server.nextSent() == Self.ticker.subscribeRequest)
            await server.acknowledge("ticker")
            try await server.push("push.ticker.BTC_USDT")
            #expect(try await tickers.value.count == 1)
        }

        @Test func `reconnect delays follow MEXC's Go client`() {
            let delays = (0..<8).map(StreamConnection.Timing().reconnectDelay(attempt:))
            #expect(delays == [1, 2, 4, 8, 16, 32, 60, 60].map { Duration.seconds($0) })
        }

        @Test func `the connection sends a ping each interval`() async throws {
            var timing = StreamConnection.Timing.test
            timing.pingInterval = .milliseconds(20)
            let streams = Streams.test(server, timing: timing)
            let ticker = streams.ticker("BTC_USDT")
            #expect(await server.nextSent() == Self.ticker.subscribeRequest)
            await server.acknowledge("ticker")

            #expect(await server.nextSent() == #"{"method":"ping"}"#)
            #expect(await server.nextSent() == #"{"method":"ping"}"#)
            withExtendedLifetime(ticker) {}
        }

        // MARK: Pushes

        @Test func `pushes the client can't read or route are skipped`() async throws {
            let streams = Streams.test(server)
            let tickers = Task { try await Self.take(1, from: streams.ticker("BTC_USDT")) }
            try await acknowledge(1)
            let otherMarket = ContractWrapper.with {
                $0.channel = "push.ticker"
                $0.symbol = "ETH_USDT"
                $0.tickerDetail = TickerDetail.with { $0.symbol = "ETH_USDT" }
            }
            await server.send(.binary(Data([0xFF, 0x00])))
            await server.send(.binary(try otherMarket.serializedBytes()))
            await server.send(#"{"channel":"pong","data":1}"#)
            try await server.push("push.ticker.BTC_USDT")

            #expect(try await tickers.value.map(\.symbol) == ["BTC_USDT"])
        }

        @Test func `a push whose values don't decode ends the stream with DecodingError`() async throws {
            let streams = Streams.test(server)
            let prices = Task { try await Self.take(1, from: streams.fairPrice("BTC_USDT")) }
            try await acknowledge(1)
            let push = ContractWrapper.with {
                $0.channel = "push.fair.price"
                $0.symbol = "BTC_USDT"
                $0.fairPrice = FairPrice.with { $0.price = "not a number" }
            }
            await server.send(.binary(try push.serializedBytes()))

            await #expect(throws: DecodingError.self) { try await prices.value }
        }

        // MARK: Helpers

        private static func tickerPush(time: Int64) throws -> Data {
            try ContractWrapper.with {
                $0.channel = "push.ticker"
                $0.symbol = "BTC_USDT"
                $0.ts = time
                $0.tickerDetail = TickerDetail.with { $0.symbol = "BTC_USDT" }
            }.serializedBytes()
        }

        private func makeConnection() -> StreamConnection {
            StreamConnection(url: URL(string: "wss://contract.mexc.com/edge")!, transport: server, timing: .test)
        }

        /// Acknowledges the next `count` subscribe requests, and returns them.
        @discardableResult
        private func acknowledge(_ count: Int) async throws -> [String] {
            var acknowledged: [String] = []
            for _ in 0..<count {
                let sent = await server.nextSent()
                await server.acknowledge(try Self.channel(of: sent))
                acknowledged.append(sent)
            }
            return acknowledged
        }

        /// The first `count` values of `stream`, or fewer if the task is cancelled first.
        private static func take<Element>(
            _ count: Int, from stream: AsyncThrowingStream<Element, any Error>
        ) async throws -> [Element] {
            var values: [Element] = []
            for try await value in stream {
                values.append(value)
                if values.count == count { break }
            }
            return values
        }

        private static func step(_ step: String) -> StreamSubscription {
            StreamSubscription(
                name: "DOGE_USDT order books grouped by step \(step)", channel: "depth.step", symbol: "DOGE_USDT",
                parameters: ["step": .string(step)]
            )
        }

        /// The channel of a subscribe request, such as `ticker` for `{"method":"sub.ticker",…}`.
        private static func channel(of request: String) throws -> String {
            let method = try #require(request.split(separator: "\"").dropFirst(3).first)
            return String(method.dropFirst("sub.".count))
        }
    }
}

/// A consumer that keeps what the connection hands it.
private final class Recorder: Sendable {
    let id = UUID()
    private let pushes: AsyncStream<ContractWrapper>
    private let continuation: AsyncStream<ContractWrapper>.Continuation

    init() {
        (pushes, continuation) = AsyncStream.makeStream()
    }

    var consumer: StreamConnection.Consumer {
        StreamConnection.Consumer(
            receive: { [continuation] in continuation.yield($0) },
            fail: { [continuation] _ in continuation.finish() }
        )
    }

    func nextPush() async -> ContractWrapper? {
        var iterator = pushes.makeAsyncIterator()
        return await iterator.next()
    }
}
