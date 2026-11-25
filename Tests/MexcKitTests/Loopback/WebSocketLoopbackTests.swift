import Foundation
import MexcKitTestSupport
import Testing

@testable import MexcKit

extension MexcKitTests {
    /// Streams over a real WebSocket to a server on 127.0.0.1.
    @Suite("WebSocket loopback", .timeLimit(.minutes(1)))
    struct WebSocketLoopbackTests {
        @Test func `the transport reads frames larger than 16 KiB, in order`() async throws {
            let tickers = try Fixture.push("push.tickers")
            #expect(tickers.count > 100_000)
            try await LoopbackWebSocketServer.run { server in
                let session = try await WebSocketKitTransport().connect(to: server.url)
                await server.waitForClient()
                let numbers = (0..<300).map(String.init)
                try await server.send(tickers)
                try await server.send(numbers)
                var frames = session.frames.makeAsyncIterator()
                #expect(await frames.next() == .binary(tickers))
                var received: [WebSocketFrame] = []
                for _ in 0...numbers.count {
                    received.append(try #require(await frames.next()))
                }
                #expect(received == (numbers + ["end"]).map(WebSocketFrame.text))

                try await server.closeClient()
                #expect(await frames.next() == nil)
            }
        }

        @Test func `connecting to a server that never upgrades throws connectionFailed after the timeout`() async throws {
            try await LoopbackServer.run(answering: .never) { server in
                var transport = WebSocketKitTransport()
                transport.connectTimeout = .milliseconds(200)
                var url = URLComponents(url: server.url, resolvingAgainstBaseURL: false)!
                url.scheme = "ws"
                let error = try await #require(throws: MexcFutures.ClientError.self) {
                    _ = try await transport.connect(to: url.url!)
                }
                #expect(error.reason == .connectionFailed)
            }
        }

        @Test func `a client streams a ticker and closes the connection when the stream ends`() async throws {
            try await LoopbackWebSocketServer.run { server in
                let client = MexcFutures.Client(configuration: .init(streamURL: server.url))
                let ticker = Task { () -> MexcFutures.Ticker? in
                    for try await ticker in client.stream.ticker("BTC_USDT") {
                        return ticker
                    }
                    return nil
                }
                var received = server.received.makeAsyncIterator()
                #expect(await received.next() == #"{"method":"sub.ticker","param":{"symbol":"BTC_USDT"}}"#)
                try await server.send(#"{"channel":"rs.sub.ticker","data":"success","ts":1}"#)
                try await server.send(try Fixture.push("push.ticker.BTC_USDT"))

                #expect(try await ticker.value?.lastPrice == Decimal(string: "60391.5"))
                // The stream ended, so the client closes the connection.
                #expect(await received.next() == nil)
            }
        }
    }
}
