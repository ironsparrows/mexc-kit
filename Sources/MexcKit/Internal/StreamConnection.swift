import Foundation
import MexcKitProtobuf
import SwiftProtobuf

/// A WebSocket connection to MEXC's channels, shared by every stream of one client that uses it: one
/// for the public channels, and one for the account's private channels.
///
/// It connects when the first subscription starts and closes when the last one ends. Subscribe
/// requests go up as JSON text frames, one at a time, each waiting for MEXC's acknowledgement before
/// the next, because MEXC's error frame doesn't say which request failed; when one doesn't come in
/// time, the connection starts over, since a late one couldn't be told from the next request's.
/// Unsubscribe requests wait for nothing. Pushes come down as binary `ContractWrapper` frames, in order, to every consumer of
/// their route. A JSON ping every 15 seconds keeps the connection open. After a drop it reconnects,
/// waiting 1 second and doubling up to 60 seconds between attempts, and subscribes again to every
/// route still consumed.
///
/// A private connection logs in first and then sends one `personal.filter` naming every private
/// channel its streams consume and their markets, sent again whenever that changes; MEXC
/// acknowledges the login but not the filter. While a stream consumes a private channel the filter
/// has no key for, such as `personal.track.order`, the filter is empty instead, which MEXC documents
/// as restoring its pushes. When the last stream ends, it closes rather than send a filter.
actor StreamConnection {
    private let url: URL
    private let transport: any WebSocketTransport
    /// How a private connection logs in; `nil` for the public one.
    private let account: Account?
    private let timing: Timing

    private var topics: [StreamSubscription.Route: Topic] = [:]
    /// Subscriptions MEXC may still push, whose consumers have all ended.
    private var unsubscribes: [StreamSubscription] = []
    private var link: Link?
    private var nextLinkID = 0
    /// The number of the next connection attempt since a drop or a failed attempt, which sets how
    /// long it waits; `nil` when the next attempt connects at once.
    private var reconnectAttempt: Int?
    /// The wait before a reconnect attempt, cancelled when the last stream ends.
    private var backoff: Task<Void, Never>?
    private var acknowledgement: PendingAcknowledgement?
    /// Whether MEXC accepted the login on the current private connection.
    private var isLoggedIn = false
    /// The `personal.filter` request last sent on the current private connection.
    private var sentFilter: String?
    /// Connects, sends requests and reconnects, one step at a time; `nil` when there is nothing to do.
    private var worker: Task<Void, Never>?

    init(url: URL, transport: any WebSocketTransport, account: Account? = nil, timing: Timing = .init()) {
        self.url = url
        self.transport = transport
        self.account = account
        self.timing = timing
    }

    // MARK: - Connection

    /// How long the connection waits. The ping and reconnect defaults follow MEXC's official Go
    /// client (`mexc-api-demo`, `go/clients/futures/config.go`): a ping every 15 seconds, within the
    /// 10 to 20 seconds MEXC's documentation asks for, and reconnecting after 1 second, doubling to
    /// at most 60 seconds.
    struct Timing: Sendable {
        var pingInterval: Duration = .seconds(15)
        var acknowledgementTimeout: Duration = .seconds(10)
        var firstReconnectDelay: Duration = .seconds(1)
        var maximumReconnectDelay: Duration = .seconds(60)

        func reconnectDelay(attempt: Int) -> Duration {
            min(firstReconnectDelay * (1 << min(attempt, 30)), maximumReconnectDelay)
        }
    }

    /// How a private connection logs in.
    struct Account: Sendable {
        /// `nil` for a client without credentials: private streams then fail with
        /// ``MexcFutures/ClientError/Reason/missingCredentials``.
        var credentials: CredentialsProvider?
        /// The time the login is signed with.
        var clock: ServerClock
    }

    /// Something that receives the pushes of one route.
    struct Consumer: Sendable {
        /// The markets whose private pushes it wants, for the `personal.filter`; empty for every
        /// market. Unused on public channels.
        var markets: Set<MexcFutures.Symbol> = []
        /// Called with each push, in the order MEXC sent them.
        var receive: @Sendable (ContractWrapper) -> Void
        /// Called once if the subscription fails; no pushes follow.
        var fail: @Sendable (any Error) -> Void
    }

    private struct Topic {
        var subscription: StreamSubscription
        var consumers: [UUID: Consumer]
        var state: State = .pending
        /// Whether MEXC ever acknowledged this route. A route that never was fails when connecting
        /// fails; one that was waits for the reconnect.
        var wasSubscribed = false
        /// Tells this topic from a later one on the same route, made after this one's consumers ended.
        let id = UUID()

        enum State {
            /// Not requested on the current connection.
            case pending
            /// Requested; waiting for MEXC's acknowledgement.
            case requested
            /// Acknowledged by MEXC.
            case subscribed
        }
    }

    private struct Link {
        var id: Int
        var session: any WebSocketSession
        var receiving: Task<Void, Never>
        var pinging: Task<Void, Never>
    }

    /// A request waiting for MEXC's acknowledgement. The outcome can arrive before the request
    /// starts waiting, and is kept until it does.
    private struct PendingAcknowledgement {
        var id: UUID
        var channel: String
        /// What an `rs.error` reply means for this request.
        var rejection: MexcFutures.ClientError.Reason
        /// The topic a subscribe request is for, by route and identity, which the acknowledgement
        /// marks subscribed as it arrives; `nil` for the login.
        var topic: (route: StreamSubscription.Route, id: UUID)?
        var continuation: CheckedContinuation<Void, any Error>?
        var outcome: Result<Void, any Error>?
    }

    /// The connection dropped while a request waited for its acknowledgement.
    private struct ConnectionLost: Error {}

    private func wake() {
        if worker == nil {
            worker = Task { await work() }
        }
    }

    /// Brings the connection in line with ``topics``, one step at a time, until nothing is left to do.
    private func work() async {
        while true {
            if topics.isEmpty {
                unsubscribes.removeAll()
                reconnectAttempt = nil
                if let link {
                    self.link = nil
                    stop(link)
                    await link.session.close()
                    continue
                }
                break
            }
            guard let link else {
                await connect()
                continue
            }
            if account != nil {
                if !isLoggedIn {
                    await logIn(on: link)
                    continue
                }
                let filter = personalFilter
                if filter.text != sentFilter {
                    await send(filter, on: link)
                    continue
                }
                // A stream that joins without changing the filter, such as any while it's empty, is
                // covered by the filter already sent.
                markSubscribed(filter.routes)
                break
            }
            if let subscription = unsubscribes.first {
                unsubscribes.removeFirst()
                try? await link.session.send(subscription.unsubscribeRequest)
                continue
            }
            if let route = topics.first(where: { $0.value.state == .pending })?.key {
                await subscribe(route, on: link)
                continue
            }
            break
        }
        worker = nil
    }

    private func connect() async {
        if let attempt = reconnectAttempt {
            let wait = Task { [timing] in _ = try? await Task.sleep(for: timing.reconnectDelay(attempt: attempt)) }
            backoff = wait
            await wait.value
            backoff = nil
            if topics.isEmpty { return }
        }
        do {
            let session = try await transport.connect(to: url)
            reconnectAttempt = nil
            open(session)
        } catch {
            reconnectAttempt = (reconnectAttempt ?? -1) + 1
            for (route, topic) in topics where !topic.wasSubscribed {
                fail(route, with: error)
            }
        }
    }

    private func open(_ session: any WebSocketSession) {
        let id = nextLinkID
        nextLinkID += 1
        let receiving = Task { [weak self] in
            for await frame in session.frames {
                await self?.receive(frame, on: id)
            }
            await self?.closed(id)
        }
        let pinging = Task { [timing] in
            while (try? await Task.sleep(for: timing.pingInterval)) != nil {
                try? await session.send(#"{"method":"ping"}"#)
            }
        }
        link = Link(id: id, session: session, receiving: receiving, pinging: pinging)
        // A new connection logs in and filters from the start.
        isLoggedIn = false
        sentFilter = nil
    }

    // MARK: - Subscribing

    /// Adds `consumer` to the route of `subscription`, and subscribes when it's the route's first.
    ///
    /// Returns before MEXC acknowledges; a failure reaches ``Consumer/fail``. A second subscription
    /// on the same route with different parameters fails with
    /// ``MexcFutures/ClientError/Reason/invalidRequest``, because MEXC's pushes couldn't be told
    /// apart.
    func subscribe(_ subscription: StreamSubscription, id: UUID, consumer: Consumer) {
        if let account, account.credentials == nil {
            consumer.fail(MexcFutures.ClientError(.missingCredentials))
            return
        }
        let route = subscription.route
        if let topic = topics[route] {
            guard topic.subscription == subscription else {
                consumer.fail(MexcFutures.ClientError(
                    .invalidRequest,
                    message: "\(topic.subscription.name) are open, so \(subscription.name) can't be streamed at the same time"
                ))
                return
            }
            topics[route]?.consumers[id] = consumer
            // The private filter may name more markets now.
            if account != nil { wake() }
            return
        }
        topics[route] = Topic(subscription: subscription, consumers: [id: consumer])
        wake()
    }

    /// Removes the consumer, and unsubscribes when it was the route's last. When no route is left,
    /// the connection closes.
    func unsubscribe(id: UUID, from route: StreamSubscription.Route) {
        guard var topic = topics[route], topic.consumers.removeValue(forKey: id) != nil else { return }
        if !topic.consumers.isEmpty {
            topics[route] = topic
            // The private filter may name fewer markets now.
            if account != nil { wake() }
            return
        }
        topics[route] = nil
        // A request still waiting for its acknowledgement is undone when the acknowledgement arrives.
        // A private connection undoes it by sending the smaller filter instead.
        if topic.state == .subscribed, account == nil {
            unsubscribes.append(topic.subscription)
        }
        if topics.isEmpty {
            backoff?.cancel()
        }
        wake()
    }

    private func subscribe(_ route: StreamSubscription.Route, on link: Link) async {
        guard let topic = topics[route] else { return }
        let subscription = topic.subscription
        topics[route]?.state = .requested
        var outcome: Result<Void, any Error>
        do {
            try await send(
                subscription.subscribeRequest, acknowledgedOn: subscription.acknowledgementChannel,
                naming: subscription.name, rejection: .subscriptionRejected, for: (route, topic.id), over: link
            )
            outcome = .success(())
        } catch is ConnectionLost {
            return
        } catch let error as MexcFutures.ClientError where error.reason == .connectionClosed {
            // The connection can't send; close it, so it reconnects.
            await link.session.close()
            closed(link.id)
            return
        } catch {
            outcome = .failure(error)
        }
        let isCurrent = topics[route]?.id == topic.id
        // The connection can drop after the acknowledgement arrives and before this resumes. Then
        // every route is already pending again, and nothing needs undoing on the closed connection.
        let isConnected = self.link?.id == link.id
        switch outcome {
        case .success:
            if isCurrent {
                topics[route]?.wasSubscribed = true
                if isConnected {
                    topics[route]?.state = .subscribed
                }
            } else if isConnected {
                // Its consumers ended while the request was in flight; a new topic on the route, if
                // any, sends its own request.
                unsubscribes.append(subscription)
            }
        case .failure(let error) where (error as? MexcFutures.ClientError)?.reason == .acknowledgementTimedOut:
            // A late acknowledgement or error from MEXC would be taken for the next request's, as
            // neither names its market, so the connection starts over and subscribes again to every
            // route still consumed. A route MEXC had acknowledged before is among them.
            if isCurrent, topics[route]?.wasSubscribed == false {
                fail(route, with: error)
            }
            if isConnected {
                await link.session.close()
                closed(link.id)
            }
        case .failure(let error):
            if isCurrent {
                fail(route, with: error)
            }
        }
    }

    /// Sends `request` and waits for MEXC to acknowledge it on `channel`, or throws when MEXC
    /// reports an error (`rejection`), the time runs out or the connection drops. `name` says what
    /// the request is for, in a timeout's message; `topic` is the topic a subscribe request is for.
    private func send(
        _ request: String, acknowledgedOn channel: String, naming name: String,
        rejection: MexcFutures.ClientError.Reason, for topic: (route: StreamSubscription.Route, id: UUID)? = nil,
        over link: Link
    ) async throws {
        let id = UUID()
        // Expected before sending, so an acknowledgement that arrives at once isn't missed.
        acknowledgement = PendingAcknowledgement(id: id, channel: channel, rejection: rejection, topic: topic)
        defer {
            if acknowledgement?.id == id { acknowledgement = nil }
        }
        try await link.session.send(request)
        let timeout = Task { [weak self, timing] in
            guard (try? await Task.sleep(for: timing.acknowledgementTimeout)) != nil else { return }
            await self?.resolveAcknowledgement(
                id: id, with: .failure(MexcFutures.ClientError(.acknowledgementTimedOut, message: name))
            )
        }
        defer { timeout.cancel() }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            guard let pending = acknowledgement, pending.id == id else {
                continuation.resume(throwing: ConnectionLost())
                return
            }
            if let outcome = pending.outcome {
                acknowledgement = nil
                continuation.resume(with: outcome)
            } else {
                acknowledgement?.continuation = continuation
            }
        }
    }

    private func resolveAcknowledgement(id: UUID? = nil, with outcome: Result<Void, any Error>) {
        guard let pending = acknowledgement, id == nil || pending.id == id, pending.outcome == nil else { return }
        if let continuation = pending.continuation {
            acknowledgement = nil
            continuation.resume(with: outcome)
        } else {
            acknowledgement?.outcome = outcome
        }
    }

    private func fail(_ route: StreamSubscription.Route, with error: any Error) {
        guard let topic = topics.removeValue(forKey: route) else { return }
        for consumer in topic.consumers.values {
            consumer.fail(error)
        }
    }

    // MARK: - Logging in

    /// Logs in to a private connection: `{"subscribe":false,"method":"login","param":{…}}`, signed
    /// like a REST request without parameters, over the API key and the request time.
    ///
    /// MEXC's official clients put `subscribe` at the top level, where the documentation's example
    /// has it inside `param` (`mexc-api-demo`, `go/clients/futures/ws_stream.go`, `Login`). A failed
    /// login fails every private stream, as does an error the credentials provider throws.
    private func logIn(on link: Link) async {
        let request: String
        do {
            guard let credentials = account?.credentials, let clock = account?.clock else {
                throw MexcFutures.ClientError(.missingCredentials)
            }
            let signer = RequestSigner(credentials: try await credentials())
            let requestTime = String(await clock.now().millisecondsSince1970)
            request = LoginRequest(
                apiKey: signer.credentials.apiKey, requestTime: requestTime,
                signature: signer.signature(requestTime: requestTime, parameters: "")
            ).text
        } catch {
            failAll(with: error)
            return
        }
        do {
            try await send(request, acknowledgedOn: "rs.login", naming: "the login", rejection: .loginRejected, over: link)
            if self.link?.id == link.id {
                isLoggedIn = true
            }
        } catch is ConnectionLost {
            return
        } catch let error as MexcFutures.ClientError where error.reason == .connectionClosed {
            await link.session.close()
            closed(link.id)
        } catch {
            // A login on a connection that has since dropped is retried on the next one.
            if self.link?.id == link.id {
                failAll(with: error)
            }
        }
    }

    /// Sends a `personal.filter`, which MEXC doesn't acknowledge, and counts the routes it names as
    /// subscribed.
    private func send(_ filter: (text: String, routes: [StreamSubscription.Route]), on link: Link) async {
        do {
            try await link.session.send(filter.text)
        } catch {
            await link.session.close()
            closed(link.id)
            return
        }
        guard self.link?.id == link.id else { return }
        sentFilter = filter.text
        markSubscribed(filter.routes)
    }

    /// Counts the routes a filter sent on the current connection names as subscribed.
    private func markSubscribed(_ routes: [StreamSubscription.Route]) {
        for route in routes where topics[route] != nil {
            topics[route]?.state = .subscribed
            topics[route]?.wasSubscribed = true
        }
    }

    /// The `personal.filter` request for the private routes consumed now, such as
    /// `{"method":"personal.filter","param":{"filters":[{"filter":"order","rules":["BTC_USDT"]}]}}`,
    /// and the routes it covers. A filter names no markets when a consumer wants every market.
    private var personalFilter: (text: String, routes: [StreamSubscription.Route]) {
        // MEXC's documentation doesn't say whether a channel without a filter key is pushed while a
        // filter is in place. It documents an empty filter as restoring its pushes, and Mexc.Net
        // receives these channels after one (with a login that keeps MEXC's default pushes on).
        if topics.values.contains(where: { $0.subscription.filter == nil }) {
            return (PersonalFilter(filters: []).text, Array(topics.keys))
        }
        let entries = topics.compactMap { route, topic -> (PersonalFilter.Entry, StreamSubscription.Route)? in
            guard let key = topic.subscription.filter else { return nil }
            let markets = topic.consumers.values.map(\.markets)
            let rules = markets.contains(where: \.isEmpty) ? nil : Set(markets.joined()).map(\.rawValue).sorted()
            return (PersonalFilter.Entry(filter: key, rules: rules), route)
        }
        let filters = entries.map(\.0).sorted { $0.filter < $1.filter }
        return (PersonalFilter(filters: filters).text, entries.map(\.1))
    }

    private func failAll(with error: any Error) {
        for route in topics.keys {
            fail(route, with: error)
        }
    }

    // MARK: - Receiving

    private func receive(_ frame: WebSocketFrame, on linkID: Int) {
        // Frames a closed connection had buffered are dropped.
        guard link?.id == linkID else { return }
        switch frame {
        case .text(let text):
            guard let control = try? JSONDecoder().decode(ControlFrame.self, from: Data(text.utf8)) else { return }
            guard let pending = acknowledgement else { return }
            if control.channel == "rs.error" {
                resolveAcknowledgement(with: .failure(MexcFutures.ClientError(pending.rejection, message: control.message)))
            } else if control.channel == pending.channel {
                // An acknowledgement says "success"; anything else on its channel is a refusal.
                if let message = control.message, message != "success" {
                    resolveAcknowledgement(with: .failure(MexcFutures.ClientError(pending.rejection, message: message)))
                    return
                }
                // Pushes that follow are this subscription's, so it counts as subscribed from here,
                // before the request's own task resumes.
                if let topic = pending.topic, topics[topic.route]?.id == topic.id {
                    topics[topic.route]?.state = .subscribed
                }
                resolveAcknowledgement(with: .success(()))
            }
        case .binary(let bytes):
            // A frame that doesn't decode is dropped, as is one of a channel no stream consumes. On
            // the market connection, so is one of a route MEXC hasn't acknowledged yet: until it
            // does, pushes on the route can still be those of the parameters it unsubscribed.
            guard let wrapper = try? ContractWrapper(serializedBytes: bytes),
                let topic = topics[wrapper.route],
                account != nil || topic.state == .subscribed
            else { return }
            for consumer in topic.consumers.values {
                consumer.receive(wrapper)
            }
        }
    }

    // MARK: - Recovering

    private func closed(_ id: Int) {
        guard let link, link.id == id else { return }
        self.link = nil
        stop(link)
        isLoggedIn = false
        sentFilter = nil
        reconnectAttempt = 0
        resolveAcknowledgement(with: .failure(ConnectionLost()))
        unsubscribes.removeAll()
        for route in topics.keys {
            topics[route]?.state = .pending
        }
        wake()
    }

    private func stop(_ link: Link) {
        link.receiving.cancel()
        link.pinging.cancel()
    }

    // MARK: - Wire

    private struct LoginRequest: Encodable {
        var method = "login"
        var subscribe = false
        var param: Parameters

        struct Parameters: Encodable {
            var apiKey: String
            var reqTime: String
            var signature: String
        }

        init(apiKey: String, requestTime: String, signature: String) {
            param = Parameters(apiKey: apiKey, reqTime: requestTime, signature: signature)
        }

        var text: String { String(decoding: try! JSONEncoder.requestBody.encode(self), as: UTF8.self) }
    }

    private struct PersonalFilter: Encodable {
        var method = "personal.filter"
        var param: Parameters

        struct Parameters: Encodable {
            var filters: [Entry]
        }

        struct Entry: Encodable {
            var filter: String
            /// `nil` for every market; MEXC's clients leave `rules` out then.
            var rules: [String]?
        }

        init(filters: [Entry]) {
            param = Parameters(filters: filters)
        }

        var text: String { String(decoding: try! JSONEncoder.requestBody.encode(self), as: UTF8.self) }
    }

    /// A text frame: an acknowledgement such as `{"channel":"rs.sub.deal","data":"success"}`, an
    /// error such as `{"channel":"rs.error","data":"Contract [NOPE_USDT] not exists"}`, or a pong.
    private struct ControlFrame: Decodable {
        var channel: String
        var message: String?

        private enum CodingKeys: String, CodingKey {
            case channel, data
        }

        // `Swift.Decoder`: SwiftProtobuf has a `Decoder` of its own.
        init(from decoder: any Swift.Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            channel = try container.decode(String.self, forKey: .channel)
            message = try? container.decode(String.self, forKey: .data)
        }
    }
}

extension ContractWrapper {
    /// The route of this push: its channel without `push.`, its market, and for candles the interval.
    fileprivate var route: StreamSubscription.Route {
        let channel = channel.hasPrefix("push.") ? String(channel.dropFirst("push.".count)) : channel
        // Private pushes are routed by channel alone; each stream keeps its own markets.
        if channel.hasPrefix("personal.") {
            return StreamSubscription.Route(channel: channel, symbol: "", variant: nil)
        }
        var variant: String?
        if case .wsKline(let candle) = data {
            variant = MexcFutures.Candle.Interval(candle.interval)?.rawValue
        }
        return StreamSubscription.Route(channel: channel, symbol: symbol, variant: variant)
    }
}
