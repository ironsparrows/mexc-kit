import Foundation
import MexcKitProtobuf
import SwiftProtobuf

/// The WebSocket connection to MEXC's public channels, shared by every stream of one client.
///
/// It connects when the first subscription starts and closes when the last one ends. Subscribe
/// requests go up as JSON text frames, one at a time, each waiting for MEXC's acknowledgement before
/// the next, because MEXC's error frame doesn't say which request failed; unsubscribe requests wait
/// for nothing. Pushes come down as binary `ContractWrapper` frames, in order, to every consumer of
/// their route. A JSON ping every 15 seconds keeps the connection open. After a drop it reconnects,
/// waiting 1 second and doubling up to 60 seconds between attempts, and subscribes again to every
/// route still consumed.
actor StreamConnection {
    private let url: URL
    private let transport: any WebSocketTransport
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
    /// Connects, sends requests and reconnects, one step at a time; `nil` when there is nothing to do.
    private var worker: Task<Void, Never>?

    init(url: URL, transport: any WebSocketTransport, timing: Timing = .init()) {
        self.url = url
        self.transport = transport
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

    /// Something that receives the pushes of one route.
    struct Consumer: Sendable {
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
    }

    // MARK: - Subscribing

    /// Adds `consumer` to the route of `subscription`, and subscribes when it's the route's first.
    ///
    /// Returns before MEXC acknowledges; a failure reaches ``Consumer/fail``. A second subscription
    /// on the same route with different parameters fails with
    /// ``MexcFutures/ClientError/Reason/invalidRequest``, because MEXC's pushes couldn't be told
    /// apart.
    func subscribe(_ subscription: StreamSubscription, id: UUID, consumer: Consumer) {
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
            return
        }
        topics[route] = nil
        // A request still waiting for its acknowledgement is undone when the acknowledgement arrives.
        if topic.state == .subscribed {
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
            try await send(subscription, over: link)
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
        case .failure(let error):
            if isConnected, (error as? MexcFutures.ClientError)?.reason == .acknowledgementTimedOut {
                // MEXC may still have subscribed.
                unsubscribes.append(subscription)
            }
            if isCurrent {
                fail(route, with: error)
            }
        }
    }

    /// Sends the subscribe request and waits for MEXC to acknowledge it, or throws when MEXC
    /// reports an error, the time runs out or the connection drops.
    private func send(_ subscription: StreamSubscription, over link: Link) async throws {
        let id = UUID()
        // Expected before sending, so an acknowledgement that arrives at once isn't missed.
        acknowledgement = PendingAcknowledgement(id: id, channel: subscription.acknowledgementChannel)
        defer {
            if acknowledgement?.id == id { acknowledgement = nil }
        }
        try await link.session.send(subscription.subscribeRequest)
        let timeout = Task { [weak self, timing] in
            guard (try? await Task.sleep(for: timing.acknowledgementTimeout)) != nil else { return }
            await self?.resolveAcknowledgement(
                id: id, with: .failure(MexcFutures.ClientError(.acknowledgementTimedOut, message: subscription.name))
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

    // MARK: - Receiving

    private func receive(_ frame: WebSocketFrame, on linkID: Int) {
        // Frames a closed connection had buffered are dropped.
        guard link?.id == linkID else { return }
        switch frame {
        case .text(let text):
            guard let control = try? JSONDecoder().decode(ControlFrame.self, from: Data(text.utf8)) else { return }
            if control.channel == "rs.error" {
                resolveAcknowledgement(with: .failure(MexcFutures.ClientError(
                    .subscriptionRejected, message: control.message
                )))
            } else if control.channel == acknowledgement?.channel {
                resolveAcknowledgement(with: .success(()))
            }
        case .binary(let bytes):
            // A frame that doesn't decode is dropped, as is one of a channel no stream consumes.
            guard let wrapper = try? ContractWrapper(serializedBytes: bytes),
                let topic = topics[wrapper.route]
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
        var variant: String?
        if case .wsKline(let candle) = data {
            variant = MexcFutures.Candle.Interval(candle.interval)?.rawValue
        }
        return StreamSubscription.Route(channel: channel, symbol: symbol, variant: variant)
    }
}
