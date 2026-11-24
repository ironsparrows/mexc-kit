public import Foundation

extension MexcFutures {
    /// A failure the client detected itself, as opposed to one MEXC reported (``MexcError``).
    ///
    /// `localizedDescription` explains the reason in a sentence, followed by ``message`` when there
    /// is one.
    public struct ClientError: Error, Sendable, CustomStringConvertible {
        public var reason: Reason
        /// Details for diagnostics, such as the text of MEXC's stream error.
        public var message: String?

        public init(_ reason: Reason, message: String? = nil) {
            self.reason = reason
            self.message = message
        }

        public var description: String {
            guard let message, !message.isEmpty else { return "MEXC client error: \(reason)" }
            return "MEXC client error: \(reason): \(message)"
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
        /// The stream connection closed.
        public static let connectionClosed = Self("connectionClosed", summary: "The stream connection closed")
    }
}
