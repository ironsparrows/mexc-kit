import Foundation
import NIOConcurrencyHelpers
import NIOCore
import NIOHTTP1
import NIOPosix
import NIOWebSocket
import Testing

/// A WebSocket server on 127.0.0.1 that accepts one client, reports the text frames it receives and
/// sends the frames a test asks for.
final class LoopbackWebSocketServer: Sendable {
    /// The server's URL, such as `ws://127.0.0.1:52341/edge`.
    let url: URL
    /// Every text frame the client sends, in order. Finishes when the client closes.
    let received: AsyncStream<String>
    private let receivedContinuation: AsyncStream<String>.Continuation
    private let listener: any Channel
    private let client = NIOLockedValueBox<(any Channel)?>(nil)
    private let connected: AsyncStream<Void>
    private let connectedContinuation: AsyncStream<Void>.Continuation

    private init(
        url: URL, listener: any Channel, received: (AsyncStream<String>, AsyncStream<String>.Continuation),
        connected: (AsyncStream<Void>, AsyncStream<Void>.Continuation)
    ) {
        self.url = url
        self.listener = listener
        (self.received, receivedContinuation) = received
        (self.connected, connectedContinuation) = connected
    }

    /// Runs `body` with a running server, and stops the server after.
    static func run<Result>(_ body: (LoopbackWebSocketServer) async throws -> Result) async throws -> Result {
        let received = AsyncStream.makeStream(of: String.self)
        let connected = AsyncStream.makeStream(of: Void.self)
        let box = NIOLockedValueBox<LoopbackWebSocketServer?>(nil)
        let listener = try await ServerBootstrap(group: MultiThreadedEventLoopGroup.singleton)
            .childChannelInitializer { channel in
                let upgrader = NIOWebSocketServerUpgrader(
                    maxFrameSize: 1 << 24,
                    shouldUpgrade: { channel, _ in channel.eventLoop.makeSucceededFuture([:]) },
                    upgradePipelineHandler: { channel, _ in
                        box.withLockedValue { $0?.accept(channel) }
                        return channel.eventLoop.makeCompletedFuture {
                            try channel.pipeline.syncOperations.addHandler(Handler(received: received.1))
                        }
                    }
                )
                return channel.pipeline.configureHTTPServerPipeline(
                    withServerUpgrade: (upgraders: [upgrader], completionHandler: { _ in })
                )
            }
            .bind(host: "127.0.0.1", port: 0)
            .get()
        let port = try #require(listener.localAddress?.port)
        let server = LoopbackWebSocketServer(
            url: URL(string: "ws://127.0.0.1:\(port)/edge")!, listener: listener, received: received,
            connected: connected
        )
        box.withLockedValue { $0 = server }
        defer { received.1.finish() }
        do {
            let result = try await body(server)
            try await listener.close()
            return result
        } catch {
            try? await listener.close()
            throw error
        }
    }

    /// Waits until a client has connected.
    func waitForClient() async {
        var iterator = connected.makeAsyncIterator()
        _ = await iterator.next()
    }

    /// Sends a text frame to the client.
    func send(_ text: String) async throws {
        try await write(.text, ByteBuffer(string: text))
    }

    /// Sends a binary frame to the client.
    func send(_ bytes: Data) async throws {
        try await write(.binary, ByteBuffer(bytes: bytes))
    }

    /// Sends text frames to the client back to back, without waiting for each to be written.
    func send(_ texts: [String]) async throws {
        let channel = try #require(client.withLockedValue { $0 })
        for text in texts {
            channel.write(WebSocketFrame(fin: true, opcode: .text, data: ByteBuffer(string: text)), promise: nil)
        }
        try await channel.writeAndFlush(WebSocketFrame(fin: true, opcode: .text, data: ByteBuffer(string: "end")))
    }

    /// Closes the connection to the client.
    func closeClient() async throws {
        try await client.withLockedValue { $0 }?.close()
    }

    private func accept(_ channel: any Channel) {
        client.withLockedValue { $0 = channel }
        connectedContinuation.yield()
    }

    private func write(_ opcode: WebSocketOpcode, _ data: ByteBuffer) async throws {
        let channel = try #require(client.withLockedValue { $0 })
        try await channel.writeAndFlush(WebSocketFrame(fin: true, opcode: opcode, data: data))
    }
}

private final class Handler: ChannelInboundHandler {
    typealias InboundIn = WebSocketFrame
    typealias OutboundOut = WebSocketFrame

    private let received: AsyncStream<String>.Continuation

    init(received: AsyncStream<String>.Continuation) {
        self.received = received
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = unwrapInboundIn(data)
        switch frame.opcode {
        case .text:
            received.yield(String(buffer: frame.unmaskedData))
        case .connectionClose:
            received.finish()
            context.close(promise: nil)
        default:
            break
        }
    }

    func channelInactive(context: ChannelHandlerContext) {
        received.finish()
    }
}
