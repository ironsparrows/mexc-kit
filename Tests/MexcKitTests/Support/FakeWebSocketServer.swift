import Foundation
import Testing
@testable import MexcKit

/// A ``WebSocketTransport`` whose server the test plays: it reads what the client sends and sends
/// frames, acknowledgements and drops itself.
actor FakeWebSocketServer: WebSocketTransport {
    /// Yields each time the client closes a connection.
    nonisolated let closes: AsyncStream<Void>
    private let closesContinuation: AsyncStream<Void>.Continuation

    private var current: AsyncStream<WebSocketFrame>.Continuation?
    private var failingConnections = 0
    /// Connections opened, counting from 1.
    private(set) var connectionCount = 0
    /// Connection attempts, failed ones included.
    private(set) var connectAttempts = 0
    private(set) var sentCount = 0
    /// Text frames the client sent that the test hasn't read yet.
    private var unread: [String] = []
    private var reader: CheckedContinuation<String, Never>?
    /// Whether the server acknowledges a subscribe request before the client's send returns.
    private var acknowledgesAtOnce = false

    init() {
        (closes, closesContinuation) = AsyncStream.makeStream()
    }

    /// The next text frame the client sends, in order, across connections.
    func nextSent() async -> String {
        if !unread.isEmpty { return unread.removeFirst() }
        return await withCheckedContinuation { reader = $0 }
    }

    /// Makes the server acknowledge each subscribe request while the client is still sending it.
    func acknowledgeAtOnce() {
        acknowledgesAtOnce = true
    }

    /// Makes the next `count` connection attempts fail.
    func failConnections(_ count: Int) {
        failingConnections = count
    }

    func connect(to url: URL) async throws -> any WebSocketSession {
        connectAttempts += 1
        if failingConnections > 0 {
            failingConnections -= 1
            throw MexcFutures.ClientError(.connectionFailed, message: "The fake server refused")
        }
        let (frames, continuation) = AsyncStream.makeStream(of: WebSocketFrame.self)
        current = continuation
        connectionCount += 1
        return Session(server: self, connection: connectionCount, frames: frames)
    }

    /// Sends a frame on the open connection.
    func send(_ frame: WebSocketFrame) {
        current?.yield(frame)
    }

    /// Sends a text frame on the open connection.
    func send(_ text: String) {
        send(.text(text))
    }

    /// Acknowledges a subscription, as `{"channel":"rs.sub.deal","data":"success"}`.
    func acknowledge(_ channel: String) {
        send(#"{"channel":"rs.sub.\#(channel)","data":"success","ts":1}"#)
    }

    /// Sends a recorded push from `Fixtures/Stream`, such as `"push.deal.ETH_USDT"`.
    func push(_ fixture: String) throws {
        let url = try #require(Bundle.module.url(forResource: fixture, withExtension: "bin", subdirectory: "Fixtures/Stream"))
        send(.binary(try Data(contentsOf: url)))
    }

    /// Closes the open connection from the server's side.
    func drop() {
        current?.finish()
        current = nil
    }

    /// Whether a connection is open.
    var isConnected: Bool { current != nil }

    fileprivate func clientClosed(_ connection: Int) {
        guard connection == connectionCount else { return }
        drop()
        closesContinuation.yield()
    }

    fileprivate func received(_ text: String, on connection: Int) throws {
        guard current != nil, connection == connectionCount else { throw MexcFutures.ClientError(.connectionClosed) }
        sentCount += 1
        if let reader {
            self.reader = nil
            reader.resume(returning: text)
        } else {
            unread.append(text)
        }
        if acknowledgesAtOnce, text.hasPrefix(#"{"method":"sub."#),
            let method = text.split(separator: "\"").dropFirst(3).first
        {
            acknowledge(String(method.dropFirst("sub.".count)))
        }
    }

    private struct Session: WebSocketSession {
        let server: FakeWebSocketServer
        /// Which of the server's connections this is, counting from 1.
        let connection: Int
        let frames: AsyncStream<WebSocketFrame>

        func send(_ text: String) async throws {
            try await server.received(text, on: connection)
        }

        func close() async {
            await server.clientClosed(connection)
        }
    }
}

extension StreamConnection.Timing {
    /// Short waits, so tests of timeouts and reconnects finish quickly; no pings unless a test asks.
    static let test = Self(
        pingInterval: .seconds(3600), acknowledgementTimeout: .milliseconds(200),
        firstReconnectDelay: .milliseconds(10), maximumReconnectDelay: .milliseconds(40)
    )
}
