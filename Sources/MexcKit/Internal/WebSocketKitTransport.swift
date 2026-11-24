import AsyncHTTPClient
import Foundation
import NIOCore
import WebSocketKit

/// Connects with WebSocketKit, on every platform.
///
/// Frames are handed on in the order they arrive: the handlers are WebSocketKit's synchronous ones,
/// registered as the connection opens, because its `async` handlers start a task per frame, which
/// can reorder them.
struct WebSocketKitTransport: WebSocketTransport {
    /// The largest frame read. MEXC's all-market tickers frame is about 129 KB, larger than
    /// WebSocketKit's default of 16 KiB.
    var maximumFrameSize = 16 * 1024 * 1024

    /// How long connecting may take, including the TLS handshake and the WebSocket upgrade, as in
    /// MEXC's official Go client (`ws_stream.go`: a 10-second handshake timeout and connect deadline).
    var connectTimeout: Duration = .seconds(10)

    func connect(to url: URL) async throws -> any WebSocketSession {
        let (frames, continuation) = AsyncStream.makeStream(of: WebSocketFrame.self)
        let group = HTTPClient.defaultEventLoopGroup
        // WebSocketKit can report the connection open before it calls `onUpgrade`, so the socket
        // arrives through its own promise. The first of the socket, a failure and the timeout wins.
        let opened = group.any().makePromise(of: WebSocket.self)
        let timeout = opened.futureResult.eventLoop.scheduleTask(in: TimeAmount(connectTimeout)) {
            opened.fail(MexcFutures.ClientError(.connectionFailed, message: "The WebSocket didn't open in time"))
        }
        opened.futureResult.whenComplete { _ in timeout.cancel() }
        WebSocket.connect(to: url, configuration: .init(maxFrameSize: maximumFrameSize), on: group) { socket in
            socket.onText { _, text in continuation.yield(.text(text)) }
            socket.onBinary { _, buffer in continuation.yield(.binary(Data(buffer.readableBytesView))) }
            socket.onClose.whenComplete { _ in continuation.finish() }
            opened.succeed(socket)
            // A socket that opens after the timeout is closed.
            opened.futureResult.whenFailure { _ in _ = socket.close() }
        }.whenFailure { opened.fail($0) }
        do {
            return Session(socket: try await opened.futureResult.get(), frames: frames)
        } catch let error as MexcFutures.ClientError {
            continuation.finish()
            throw error
        } catch {
            continuation.finish()
            throw MexcFutures.ClientError(.connectionFailed, underlyingError: error)
        }
    }

    private struct Session: WebSocketSession {
        let socket: WebSocket
        let frames: AsyncStream<WebSocketFrame>

        func send(_ text: String) async throws {
            do {
                try await socket.send(text)
            } catch {
                throw MexcFutures.ClientError(.connectionClosed, underlyingError: error)
            }
        }

        func close() async {
            try? await socket.close()
        }
    }
}
