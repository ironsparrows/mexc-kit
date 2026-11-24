public import Foundation

extension MexcFutures {
    /// The client for MEXC's futures API.
    ///
    /// A client is a reference: every holder shares its clock offset. Public endpoints never read
    /// credentials. A private endpoint on a client without credentials throws
    /// ``ClientError/Reason/missingCredentials`` before anything is sent.
    public final class Client: Sendable {
        let rest: RESTClient
        let clock: ServerClock

        /// Creates a client with fixed credentials, or without credentials for public endpoints only.
        public convenience init(credentials: MexcCredentials? = nil, configuration: Configuration = .init()) {
            let provider: CredentialsProvider? = credentials.map { credentials in { @Sendable in credentials } }
            self.init(credentialsProvider: provider, configuration: configuration)
        }

        /// Creates a client that reads its credentials before each private request, so a key rotated
        /// while the app runs is used from the next request on.
        ///
        /// An error the closure throws ends that request unchanged, before anything is sent.
        public convenience init(
            credentials: @escaping @Sendable () async throws -> MexcCredentials,
            configuration: Configuration = .init()
        ) {
            self.init(credentialsProvider: credentials, configuration: configuration)
        }

        init(
            credentialsProvider credentials: CredentialsProvider?,
            configuration: Configuration,
            transport: any HTTPTransport = AsyncHTTPClientTransport(),
            clock: ServerClock = ServerClock()
        ) {
            self.clock = clock
            rest = RESTClient(
                baseURL: configuration.restURL,
                transport: transport,
                credentials: credentials,
                clock: clock,
                receiveWindow: configuration.receiveWindow,
                language: configuration.language,
                timeout: configuration.timeout
            )
        }

        /// Measures the offset between this device's clock and MEXC's, and applies it to the
        /// `Request-Time` of every later private request.
        ///
        /// MEXC rejects a private request whose time is more than 10 seconds off its own clock, or
        /// off by more than ``Configuration/receiveWindow`` when that is set. Call this once when the
        /// device's clock may be wrong; the offset stays until the next call.
        public func synchronizeClock() async throws {
            try await clock.synchronize { [rest] in try await rest.send(.serverTime).date }
        }
    }
}

extension MexcFutures.Client {
    /// Settings for a ``MexcFutures/Client``.
    public struct Configuration: Sendable {
        /// The REST base URL. Defaults to `https://api.mexc.com`.
        public var restURL: URL
        /// How long after its `Request-Time` MEXC still accepts a private request, sent in the
        /// `Recv-Window` header in whole milliseconds. `nil` sends no header, and MEXC allows 10
        /// seconds. MEXC accepts at most 60 seconds; the client sends the value as it is.
        public var receiveWindow: Duration?
        /// The value of the `Language` header, which selects the language of MEXC's messages. `nil`
        /// sends no header.
        public var language: String?
        /// How long a REST request may take, from sending it to the last byte of the response.
        /// Defaults to 30 seconds. A request that takes longer throws
        /// ``MexcFutures/ClientError/Reason/timedOut``.
        ///
        /// While MEXC can't be reached, the client keeps trying to connect until this time passes,
        /// then throws ``MexcFutures/ClientError/Reason/connectionFailed``. A private request that
        /// waits longer than ``receiveWindow`` (10 seconds without one) arrives too late for MEXC to
        /// accept it.
        public var timeout: Duration

        /// Creates a configuration; every setting has a default.
        public init(
            restURL: URL = URL(string: "https://api.mexc.com")!,
            receiveWindow: Duration? = nil,
            language: String? = nil,
            timeout: Duration = .seconds(30)
        ) {
            self.restURL = restURL
            self.receiveWindow = receiveWindow
            self.language = language
            self.timeout = timeout
        }
    }
}
