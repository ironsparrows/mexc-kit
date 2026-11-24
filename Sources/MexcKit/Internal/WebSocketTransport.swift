import Foundation

/// Opens WebSocket connections.
///
/// The seam between ``StreamConnection`` and the network: ``WebSocketKitTransport`` connects over
/// the network, and tests substitute a fake that scripts the server's frames.
protocol WebSocketTransport: Sendable {
    /// Connects to `url`, or throws ``MexcFutures/ClientError`` with
    /// ``MexcFutures/ClientError/Reason/connectionFailed``.
    func connect(to url: URL) async throws -> any WebSocketSession
}

/// One open WebSocket connection.
protocol WebSocketSession: Sendable {
    /// Every frame the server sends, in the order it sent them. Finishes when the connection closes.
    var frames: AsyncStream<WebSocketFrame> { get }

    /// Sends a text frame. Throws when the connection is closed.
    func send(_ text: String) async throws

    /// Closes the connection, which finishes ``frames``.
    func close() async
}

/// A data frame the server sent.
enum WebSocketFrame: Hashable, Sendable {
    case text(String)
    case binary(Data)
}
