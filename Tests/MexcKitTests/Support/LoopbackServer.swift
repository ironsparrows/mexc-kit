import Foundation
import NIOCore
import NIOHTTP1
import NIOPosix
import Testing

/// An HTTP server on 127.0.0.1 that answers every request with one canned response, or never answers,
/// and reports each request it receives.
struct LoopbackServer: Sendable {
    struct Request: Sendable {
        var method: String
        var uri: String
        var headers: [String: String]
        var body: String
    }

    enum Answer: Sendable {
        case respond(status: Int, body: String, headers: [String: String] = [:])
        /// Sends the response head and the start of a longer body, then stalls.
        case stallBody
        /// Keeps the connection open without answering.
        case never
        /// Closes the connection without answering.
        case close
    }

    /// The server's base URL, such as `http://127.0.0.1:52341`.
    let url: URL
    /// Every request the server receives, in order.
    let requests: AsyncStream<Request>
    private let channel: any Channel
    private let finishRequests: @Sendable () -> Void

    /// A URL on 127.0.0.1 where no server listens: the port was free a moment ago.
    static func unusedURL() async throws -> URL {
        let url = try await run(answering: .never) { $0.url }
        return url
    }

    /// Runs `body` with a server that answers every request with `answer`, and stops the server after.
    static func run<Result>(
        answering answer: Answer, _ body: (LoopbackServer) async throws -> Result
    ) async throws -> Result {
        let server = try await start(answering: answer)
        defer { server.finishRequests() }
        do {
            let result = try await body(server)
            try await server.channel.close()
            return result
        } catch {
            try? await server.channel.close()
            throw error
        }
    }

    private static func start(answering answer: Answer) async throws -> LoopbackServer {
        let (requests, continuation) = AsyncStream.makeStream(of: Request.self)
        let channel = try await ServerBootstrap(group: MultiThreadedEventLoopGroup.singleton)
            .childChannelInitializer { channel in
                channel.eventLoop.makeCompletedFuture {
                    try channel.pipeline.syncOperations.configureHTTPServerPipeline()
                    try channel.pipeline.syncOperations.addHandler(Handler(answer: answer, requests: continuation))
                }
            }
            .bind(host: "127.0.0.1", port: 0)
            .get()
        let port = try #require(channel.localAddress?.port)
        return LoopbackServer(
            url: URL(string: "http://127.0.0.1:\(port)")!, requests: requests, channel: channel,
            finishRequests: { continuation.finish() }
        )
    }
}

private final class Handler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let answer: LoopbackServer.Answer
    private let requests: AsyncStream<LoopbackServer.Request>.Continuation
    private var head: HTTPRequestHead?
    private var body = ""

    init(answer: LoopbackServer.Answer, requests: AsyncStream<LoopbackServer.Request>.Continuation) {
        self.answer = answer
        self.requests = requests
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        switch unwrapInboundIn(data) {
        case .head(let head):
            self.head = head
            body = ""
        case .body(let buffer):
            body += String(buffer: buffer)
        case .end:
            guard let head else { return }
            let headers = Dictionary(head.headers.map { ($0.name, $0.value) }) { first, _ in first }
            requests.yield(.init(method: head.method.rawValue, uri: head.uri, headers: headers, body: body))
            switch answer {
            case .respond(let status, let text, let headers):
                let bytes = ByteBuffer(string: text)
                writeHead(context, head, status: status, contentLength: bytes.readableBytes, headers: headers)
                context.write(wrapOutboundOut(.body(.byteBuffer(bytes))), promise: nil)
                context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
            case .stallBody:
                writeHead(context, head, status: 200, contentLength: 100, headers: [:])
                context.writeAndFlush(wrapOutboundOut(.body(.byteBuffer(ByteBuffer(string: "{")))), promise: nil)
            case .never:
                break
            case .close:
                context.close(promise: nil)
            }
        }
    }

    private func writeHead(
        _ context: ChannelHandlerContext, _ request: HTTPRequestHead, status: Int, contentLength: Int,
        headers extraHeaders: [String: String]
    ) {
        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "application/json")
        headers.add(name: "Content-Length", value: String(contentLength))
        for (name, value) in extraHeaders {
            headers.add(name: name, value: value)
        }
        let head = HTTPResponseHead(
            version: request.version, status: HTTPResponseStatus(statusCode: status), headers: headers
        )
        context.write(wrapOutboundOut(.head(head)), promise: nil)
    }
}
