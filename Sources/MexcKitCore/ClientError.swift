public import Foundation

extension MexcFutures {
    /// A failure the client detected itself, as opposed to one MEXC reported (``MexcError``).
    ///
    /// Network failures, such as a timeout or no connection, arrive as this error too, with the
    /// network library's error in ``underlyingError``. Cancelling the task throws `CancellationError`
    /// instead.
    ///
    /// `localizedDescription` explains the reason in a sentence, followed by ``message`` when there
    /// is one.
    public struct ClientError: Error, Sendable, CustomStringConvertible {
        public var reason: Reason
        /// Details for diagnostics, such as the text of MEXC's stream error.
        public var message: String?
        /// The error that caused this one, such as the network library's error behind
        /// ``Reason/timedOut``.
        ///
        /// For diagnostics only: its type differs between platforms and library versions, so don't
        /// match on it.
        public var underlyingError: (any Error)?

        public init(_ reason: Reason, message: String? = nil, underlyingError: (any Error)? = nil) {
            self.reason = reason
            self.message = message
            self.underlyingError = underlyingError
        }

        public var description: String {
            var text = "MEXC client error: \(reason)"
            if let message, !message.isEmpty { text += ": \(message)" }
            if let underlyingError { text += " (\(underlyingError))" }
            return text
        }
    }
}

extension MexcFutures.ClientError: LocalizedError {
    public var errorDescription: String? {
        guard let message, !message.isEmpty else { return reason.summary }
        return "\(reason.summary): \(message)"
    }
}

extension MexcFutures.ClientError {
    /// What went wrong.
    public struct Reason: Hashable, Sendable, CustomStringConvertible {
        private let name: String
        fileprivate let summary: String

        private init(_ name: String, summary: String) {
            self.name = name
            self.summary = summary
        }

        public var description: String { name }

        /// The request can't be sent as built, such as an order with an attached stop in a batch, or an
        /// ID that isn't a number where MEXC takes a number. ``ClientError/message`` says which.
        public static let invalidRequest = Self(
            "invalidRequest", summary: "The request can't be sent to MEXC as built"
        )
        /// A private endpoint or stream was called on a client without credentials.
        public static let missingCredentials = Self(
            "missingCredentials", summary: "The client has no API key and secret for a private request"
        )
        /// MEXC refused a stream subscription.
        public static let subscriptionRejected = Self(
            "subscriptionRejected", summary: "MEXC rejected the stream subscription"
        )
        /// MEXC refused the stream login.
        public static let loginRejected = Self("loginRejected", summary: "MEXC rejected the stream login")
        /// MEXC didn't acknowledge a stream request in time.
        public static let acknowledgementTimedOut = Self(
            "acknowledgementTimedOut", summary: "MEXC didn't acknowledge the stream request in time"
        )
        /// A stream connection that closed couldn't send. The connection reconnects on its own, so this
        /// never reaches a stream.
        package static let connectionClosed = Self("connectionClosed", summary: "The stream connection closed")
        /// MEXC didn't answer a request within the configured timeout.
        ///
        /// The request may still have reached MEXC. Before repeating one that changes something, such
        /// as placing an order, check whether it took effect.
        public static let timedOut = Self("timedOut", summary: "MEXC didn't answer in time")
        /// The client couldn't connect to MEXC, or the connection failed before the whole response
        /// arrived.
        ///
        /// When the connection failed after the request was sent, the request may still have reached
        /// MEXC. Before repeating one that changes something, such as placing an order, check whether
        /// it took effect.
        public static let connectionFailed = Self(
            "connectionFailed", summary: "The connection to MEXC failed"
        )
    }
}
