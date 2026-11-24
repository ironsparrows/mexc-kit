import Foundation
import MexcKitProtobuf

/// The live ``MexcFutures/StreamAPI``.
struct StreamEndpoints: MexcFutures.StreamAPI {
    let connection: StreamConnection

    // MARK: - Endpoints

    func ticker(_ symbol: MexcFutures.Symbol) -> AsyncThrowingStream<MexcFutures.Ticker, any Error> {
        stream(StreamSubscription(name: "\(symbol) tickers", channel: "ticker", symbol: symbol), buffering: .bufferingNewest(1)) { push in
            guard case .tickerDetail(let ticker) = push.data else { return [] }
            return [try MexcFutures.Ticker(ticker)]
        }
    }

    func tickers() -> AsyncThrowingStream<[MexcFutures.TickerSummary], any Error> {
        stream(StreamSubscription(name: "the tickers of every market", channel: "tickers"), buffering: .bufferingNewest(1)) { push in
            guard case .tickerList(let list) = push.data else { return [] }
            return [try list.ticker.map(MexcFutures.TickerSummary.init)]
        }
    }

    func deals(_ symbol: MexcFutures.Symbol, merged: Bool) -> AsyncThrowingStream<MexcFutures.Deal, any Error> {
        // `reduce` is the Protobuf switch: on by default, off sends every trade.
        let subscription = StreamSubscription(
            name: "\(symbol) \(merged ? "merged" : "unmerged") deals", channel: "deal", symbol: symbol,
            parameters: merged ? [:] : ["reduce": .bool(false)]
        )
        return stream(subscription, buffering: .unbounded) { push in
            switch push.data {
            case .deal(let deal): [try MexcFutures.Deal(deal)]
            case .deals(let deals): try deals.deals.map(MexcFutures.Deal.init)
            default: []
            }
        }
    }

    func orderBookChanges(
        _ symbol: MexcFutures.Symbol
    ) -> AsyncThrowingStream<MexcFutures.OrderBook.Change, any Error> {
        stream(StreamSubscription(name: "\(symbol) order book changes", channel: "depth", symbol: symbol), buffering: .unbounded) { push in
            guard case .depthInfo(let depth) = push.data else { return [] }
            return [try MexcFutures.OrderBook.Change(depth)]
        }
    }

    func orderBooks(_ symbol: MexcFutures.Symbol, limit: Int) -> AsyncThrowingStream<MexcFutures.OrderBook, any Error> {
        // `depth.full` works and is used by MEXC's official Go client, but isn't on the documentation's pages.
        let subscription = StreamSubscription(
            name: "\(symbol) order books of \(limit) levels", channel: "depth.full", symbol: symbol,
            parameters: ["limit": .int(limit)]
        )
        return stream(subscription, buffering: .bufferingNewest(1)) { push in
            guard case .depthInfo(let depth) = push.data else { return [] }
            let time = depth.cts != 0 ? depth.cts : push.ts
            return [try MexcFutures.OrderBook(asks: depth.asks, bids: depth.bids, version: depth.version, time: time)]
        }
    }

    func orderBooks(
        _ symbol: MexcFutures.Symbol, step: Decimal
    ) -> AsyncThrowingStream<MexcFutures.OrderBook, any Error> {
        let subscription = StreamSubscription(
            name: "\(symbol) order books grouped by step \(step)", channel: "depth.step", symbol: symbol,
            parameters: ["step": .string(step.description)]
        )
        return stream(subscription, buffering: .bufferingNewest(1)) { push in
            guard case .depthStepInfo(let depth) = push.data else { return [] }
            let time = depth.hasCt && depth.ct != 0 ? depth.ct : push.ts
            return [try MexcFutures.OrderBook(asks: depth.asks, bids: depth.bids, version: depth.version, time: time)]
        }
    }

    func candles(
        _ symbol: MexcFutures.Symbol, interval: MexcFutures.Candle.Interval
    ) -> AsyncThrowingStream<MexcFutures.Candle, any Error> {
        let subscription = StreamSubscription(
            name: "\(symbol) \(interval.rawValue) candles", channel: "kline", symbol: symbol,
            parameters: ["interval": .string(interval.rawValue)], variant: interval.rawValue
        )
        return stream(subscription, buffering: .bufferingNewest(1)) { push in
            guard case .wsKline(let candle) = push.data else { return [] }
            return [try MexcFutures.Candle(candle)]
        }
    }

    func indexPrice(_ symbol: MexcFutures.Symbol) -> AsyncThrowingStream<MexcFutures.PriceSnapshot, any Error> {
        stream(StreamSubscription(name: "\(symbol) index prices", channel: "index.price", symbol: symbol), buffering: .bufferingNewest(1)) { push in
            guard case .indexPrice(let price) = push.data else { return [] }
            return [try MexcFutures.PriceSnapshot(symbol: price.symbol, price: price.price, time: push.ts)]
        }
    }

    func fairPrice(_ symbol: MexcFutures.Symbol) -> AsyncThrowingStream<MexcFutures.PriceSnapshot, any Error> {
        stream(StreamSubscription(name: "\(symbol) fair prices", channel: "fair.price", symbol: symbol), buffering: .bufferingNewest(1)) { push in
            guard case .fairPrice(let price) = push.data else { return [] }
            return [try MexcFutures.PriceSnapshot(symbol: price.symbol, price: price.price, time: push.ts)]
        }
    }

    /// A stream of the values `elements` reads from each push of `subscription`.
    ///
    /// Making the stream subscribes; ending it, by cancelling the iterating task or releasing the
    /// stream, unsubscribes. A push whose values don't decode ends the stream with a `DecodingError`.
    private func stream<Element: Sendable>(
        _ subscription: StreamSubscription,
        buffering: AsyncThrowingStream<Element, any Error>.Continuation.BufferingPolicy,
        elements: @escaping @Sendable (ContractWrapper) throws -> [Element]
    ) -> AsyncThrowingStream<Element, any Error> {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: Element.self, bufferingPolicy: buffering)
        let id = UUID()
        let consumer = StreamConnection.Consumer(
            receive: { push in
                do {
                    for element in try elements(push) {
                        continuation.yield(element)
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            },
            fail: { continuation.finish(throwing: $0) }
        )
        let subscribing = Task { [connection] in
            await connection.subscribe(subscription, id: id, consumer: consumer)
        }
        continuation.onTermination = { [connection] _ in
            // After the subscription is in place, so the removal can't arrive first.
            Task {
                await subscribing.value
                await connection.unsubscribe(id: id, from: subscription.route)
            }
        }
        return stream
    }
}

// MARK: - Wire

extension MexcFutures.Ticker {
    fileprivate init(_ ticker: TickerDetail) throws {
        self.init(
            symbol: MexcFutures.Symbol(rawValue: ticker.symbol),
            lastPrice: try .stream(ticker.lastPrice, "lastPrice"),
            bestBid: try .streamIfPresent(ticker.bid1, "bid1"),
            bestAsk: try .streamIfPresent(ticker.ask1, "ask1"),
            indexPrice: try .stream(ticker.indexPrice, "indexPrice"),
            fairPrice: try .stream(ticker.fairPrice, "fairPrice"),
            fundingRate: try .stream(ticker.fundingRate, "fundingRate"),
            openInterest: try .stream(ticker.holdVol, "holdVol"),
            high24h: try .stream(ticker.high24Price, "high24Price"),
            low24h: try .stream(ticker.lower24Price, "lower24Price"),
            volume24h: try .stream(ticker.volume24, "volume24"),
            turnover24h: try .stream(ticker.amount24, "amount24"),
            dayChange: try .stream(ticker.riseFallValue, "riseFallValue"),
            dayChangeRate: try .stream(ticker.riseFallRate, "riseFallRate"),
            maximumBidPrice: try .stream(ticker.maxBidPrice, "maxBidPrice"),
            minimumAskPrice: try .stream(ticker.minAskPrice, "minAskPrice"),
            time: Date(milliseconds: ticker.timestamp)
        )
    }
}

extension MexcFutures.TickerSummary {
    fileprivate init(_ ticker: MexcKitProtobuf.Ticker) throws {
        self.init(
            symbol: MexcFutures.Symbol(rawValue: ticker.symbol),
            lastPrice: try .stream(ticker.lastPrice, "lastPrice"),
            indexPrice: try .stream(ticker.indexPrice, "indexPrice"),
            fairPrice: try .stream(ticker.fairPrice, "fairPrice"),
            high24h: try .stream(ticker.high24Price, "high24Price"),
            low24h: try .stream(ticker.lower24Price, "lower24Price"),
            volume24h: try .stream(ticker.volume24, "volume24"),
            turnover24h: try .stream(ticker.amount24, "amount24"),
            dayChangeRate: try .stream(ticker.riseFallRate, "riseFallRate"),
            maximumBidPrice: try .stream(ticker.maxBidPrice, "maxBidPrice"),
            minimumAskPrice: try .stream(ticker.minAskPrice, "minAskPrice"),
            time: Date(milliseconds: ticker.timestamp)
        )
    }
}

extension MexcFutures.Deal {
    fileprivate init(_ deal: MexcKitProtobuf.Deal) throws {
        guard deal.hasT, deal.hasO, deal.hasM else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "A deal is missing its t, o or m")
            )
        }
        self.init(
            id: deal.hasI ? String(deal.i) : nil,
            price: try .stream(deal.p, "p"),
            volume: try .stream(deal.v, "v"),
            takerSide: TakerSide(rawValue: Int(deal.t)),
            positionEffect: PositionEffect(rawValue: Int(deal.o)),
            // MEXC's deal page: 1 is a self-trade, 2 isn't.
            isSelfTrade: deal.m == 1,
            // `ts` is the trade time; `cts` is the matching engine's, sent when `ts` isn't.
            time: Date(milliseconds: deal.hasTs ? deal.ts : deal.cts)
        )
    }
}

extension MexcFutures.OrderBook {
    fileprivate init(asks: [DepthItem], bids: [DepthItem], version: Int64, time: Int64) throws {
        self.init(
            asks: try asks.map(Level.init),
            bids: try bids.map(Level.init),
            version: version,
            time: Date(milliseconds: time)
        )
    }
}

extension MexcFutures.OrderBook.Change {
    fileprivate init(_ depth: DepthInfo) throws {
        self.init(
            asks: try depth.asks.map(MexcFutures.OrderBook.Level.init),
            bids: try depth.bids.map(MexcFutures.OrderBook.Level.init),
            version: depth.version
        )
    }
}

extension MexcFutures.OrderBook.Level {
    fileprivate init(_ item: DepthItem) throws {
        self.init(price: try .stream(item.price, "price"), volume: try .stream(item.vol, "vol"), orderCount: Int(item.count))
    }
}

extension MexcFutures.Candle {
    fileprivate init(_ candle: WsKLine) throws {
        self.init(
            time: Date(timeIntervalSince1970: TimeInterval(candle.t)),
            open: try .stream(candle.o, "o"),
            high: try .stream(candle.h, "h"),
            low: try .stream(candle.l, "l"),
            close: try .stream(candle.c, "c"),
            volume: try .stream(candle.q, "q"),
            turnover: try .stream(candle.a, "a")
        )
    }
}

extension MexcFutures.Candle.Interval {
    /// The interval of a Protobuf candle, with the name MEXC's requests use; `nil` for a number the
    /// generated code doesn't know.
    init?(_ interval: MexcKitProtobuf.Interval) {
        switch interval {
        case .second1: self.init(rawValue: "Second1")
        case .min1: self = .oneMinute
        case .min5: self = .fiveMinutes
        case .min15: self = .fifteenMinutes
        case .min30: self = .thirtyMinutes
        case .min60: self = .oneHour
        case .hour4: self = .fourHours
        case .hour8: self = .eightHours
        case .day1: self = .oneDay
        case .week1: self = .oneWeek
        case .month1: self = .oneMonth
        default: return nil
        }
    }
}

extension MexcFutures.PriceSnapshot {
    fileprivate init(symbol: String, price: String, time: Int64) throws {
        self.init(
            symbol: MexcFutures.Symbol(rawValue: symbol),
            price: try .stream(price, "price"),
            time: Date(milliseconds: time)
        )
    }
}

extension Decimal {
    /// A decimal Protobuf sends as a string, such as `"60391.6"`.
    fileprivate static func stream(_ text: String, _ field: String) throws -> Decimal {
        guard let value = Decimal(string: text) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "\(field) isn't a decimal: \"\(text)\"")
            )
        }
        return value
    }

    /// A decimal Protobuf sends as a string, or `nil` when the string is empty.
    fileprivate static func streamIfPresent(_ text: String, _ field: String) throws -> Decimal? {
        text.isEmpty ? nil : try stream(text, field)
    }
}

extension Date {
    fileprivate init(milliseconds: Int64) {
        self.init(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
}
