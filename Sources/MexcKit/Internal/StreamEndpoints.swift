import Foundation
import MexcKitProtobuf

/// The live ``MexcFutures/StreamAPI``.
struct StreamEndpoints: MexcFutures.StreamAPI {
    /// The connection of the market streams.
    let connection: StreamConnection
    /// The logged-in connection of the account streams.
    let accountConnection: StreamConnection

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

    func orders(_ symbols: Set<MexcFutures.Symbol>) -> AsyncThrowingStream<MexcFutures.Order, any Error> {
        accountStream("orders", channel: "order", markets: symbols) { push in
            guard case .orderChange(let order) = push.data else { return nil }
            return (order.symbol, { try MexcFutures.Order(order) })
        }
    }

    func fills(_ symbols: Set<MexcFutures.Symbol>) -> AsyncThrowingStream<MexcFutures.Fill, any Error> {
        accountStream("fills", channel: "order.deal", markets: symbols) { push in
            guard case .orderDealDetail(let fill) = push.data else { return nil }
            return (fill.symbol, { try MexcFutures.Fill(fill) })
        }
    }

    func positions(_ symbols: Set<MexcFutures.Symbol>) -> AsyncThrowingStream<MexcFutures.Position, any Error> {
        accountStream("positions", channel: "position", markets: symbols) { push in
            guard case .positionChange(let position) = push.data else { return nil }
            return (position.symbol, { try MexcFutures.Position(position) })
        }
    }

    func balances() -> AsyncThrowingStream<MexcFutures.BalanceUpdate, any Error> {
        accountStream("balances", channel: "asset", markets: []) { push in
            guard case .assetChange(let balance) = push.data else { return nil }
            return (nil, { try MexcFutures.BalanceUpdate(balance) })
        }
    }

    /// An account stream of the pushes of `push.personal.<channel>`, whose `personal.filter` key is
    /// `channel` too.
    ///
    /// `value` gives a push's market, `nil` for one of the whole account, and how to read it. A push
    /// of another market than `markets` is dropped before it is read, so it can't end this stream;
    /// MEXC's filter names the markets of every stream of the channel.
    private func accountStream<Element: Sendable>(
        _ name: String, channel: String, markets: Set<MexcFutures.Symbol>,
        value: @escaping @Sendable (ContractWrapper) -> (market: String?, read: () throws -> Element)?
    ) -> AsyncThrowingStream<Element, any Error> {
        let subscription = StreamSubscription(name: "the account's \(name)", channel: "personal.\(channel)", filter: channel)
        return stream(subscription, on: accountConnection, markets: markets, buffering: .unbounded) { push in
            guard let (market, read) = value(push) else { return [] }
            if let market, !markets.isEmpty, !markets.contains(MexcFutures.Symbol(rawValue: market)) { return [] }
            return [try read()]
        }
    }

    /// A stream of the values `elements` reads from each push of `subscription`.
    ///
    /// Making the stream subscribes; ending it, by cancelling the iterating task or releasing the
    /// stream, unsubscribes. A push whose values don't decode ends the stream with a `DecodingError`.
    private func stream<Element: Sendable>(
        _ subscription: StreamSubscription, on connection: StreamConnection? = nil, markets: Set<MexcFutures.Symbol> = [],
        buffering: AsyncThrowingStream<Element, any Error>.Continuation.BufferingPolicy,
        elements: @escaping @Sendable (ContractWrapper) throws -> [Element]
    ) -> AsyncThrowingStream<Element, any Error> {
        let connection = connection ?? self.connection
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: Element.self, bufferingPolicy: buffering)
        let id = UUID()
        let consumer = StreamConnection.Consumer(
            markets: markets,
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

extension MexcFutures.Order {
    fileprivate init(_ order: OrderChange) throws {
        self.init(
            id: MexcFutures.OrderID(rawValue: try required(order.orderID, "orderId")),
            symbol: MexcFutures.Symbol(rawValue: try required(order.symbol, "symbol")),
            position: order.hasPositionID && order.positionID != 0 ? MexcFutures.PositionID(rawValue: String(order.positionID)) : nil,
            side: MexcFutures.OrderSide(rawValue: try requiredNonZero(order.side, "side")),
            type: MexcFutures.OrderType(rawValue: try requiredNonZero(order.orderType, "orderType")),
            category: MexcFutures.OrderCategory(rawValue: try requiredNonZero(order.category, "category")),
            state: MexcFutures.OrderState(rawValue: try requiredNonZero(order.state, "state")),
            marginMode: MexcFutures.MarginMode(rawValue: try requiredNonZero(order.openType, "openType")),
            leverage: Int(try required(order.hasLeverage, order.leverage, "leverage")),
            price: try .stream(order.price, "price"),
            volume: try .stream(order.vol, "vol"),
            filledVolume: try .stream(order.dealVol, "dealVol"),
            averageFillPrice: try Decimal.streamIfPresent(order.dealAvgPrice, "dealAvgPrice").flatMap { $0 == 0 ? nil : $0 },
            margin: try .stream(order.orderMargin, "orderMargin"),
            usedMargin: try .streamIfPresent(order.usedMargin, "usedMargin"),
            takerFee: try .stream(order.takerFee, "takerFee"),
            makerFee: try .stream(order.makerFee, "makerFee"),
            totalFee: nil,
            feeAsset: try required(order.feeCurrency, "feeCurrency"),
            profit: try .stream(order.profit, "profit"),
            takeProfit: nil,
            stopLoss: nil,
            bestPrice: order.bboTypeNum == 0 ? nil : MexcFutures.BestPrice(rawValue: Int(order.bboTypeNum)),
            externalID: order.externalOid.isEmpty ? nil : MexcFutures.ExternalOrderID(rawValue: order.externalOid),
            errorCode: MexcFutures.OrderErrorCode(rawValue: Int(order.errorCode)),
            positionMode: order.positionMode == 0 ? nil : MexcFutures.PositionMode(rawValue: Int(order.positionMode)),
            reduceOnly: order.hasReduceOnly ? order.reduceOnly : nil,
            triggerProtection: nil,
            createdAt: Date(milliseconds: try required(order.hasCreateTime, order.createTime, "createTime")),
            updatedAt: order.hasUpdateTime ? Date(milliseconds: order.updateTime) : nil
        )
    }
}

extension MexcFutures.Fill {
    fileprivate init(_ fill: OrderDealDetail) throws {
        self.init(
            id: MexcFutures.FillID(rawValue: try required(fill.id, "id")),
            symbol: MexcFutures.Symbol(rawValue: try required(fill.symbol, "symbol")),
            orderID: fill.orderID.isEmpty ? nil : MexcFutures.OrderID(rawValue: fill.orderID),
            side: MexcFutures.OrderSide(rawValue: try requiredNonZero(fill.side, "side")),
            price: try .stream(fill.price, "price"),
            volume: try .stream(fill.vol, "vol"),
            fee: try .stream(fill.fee, "fee"),
            feeAsset: try required(fill.feeCurrency, "feeCurrency"),
            profit: try .streamIfPresent(fill.profit, "profit"),
            category: fill.category == 0 ? nil : MexcFutures.OrderCategory(rawValue: Int(fill.category)),
            isTaker: fill.taker,
            positionMode: fill.positionMode == 0 ? nil : MexcFutures.PositionMode(rawValue: Int(fill.positionMode)),
            filledAt: Date(milliseconds: try required(fill.hasTimestamp, fill.timestamp, "timestamp"))
        )
    }
}

extension MexcFutures.Position {
    fileprivate init(_ position: PositionChange) throws {
        self.init(
            id: MexcFutures.PositionID(rawValue: String(try requiredNonZero(position.positionID, "positionId"))),
            symbol: MexcFutures.Symbol(rawValue: try required(position.symbol, "symbol")),
            side: MexcFutures.PositionSide(rawValue: try requiredNonZero(position.positionType, "positionType")),
            marginMode: MexcFutures.MarginMode(rawValue: try requiredNonZero(position.openType, "openType")),
            state: MexcFutures.PositionState(rawValue: try requiredNonZero(position.state, "state")),
            leverage: Int(try required(position.hasLeverage, position.leverage, "leverage")),
            volume: try .stream(position.holdVol, "holdVol"),
            frozenVolume: try .stream(position.frozenVol, "frozenVol"),
            closedVolume: try .stream(position.closeVol, "closeVol"),
            // The `FullyScale` strings carry digits the plain ones may round away, as in REST.
            averagePrice: try .streamIfPresent(position.holdAvgPriceFullyScale, "holdAvgPriceFullyScale")
                ?? .stream(position.holdAvgPrice, "holdAvgPrice"),
            averageOpenPrice: try .streamIfPresent(position.openAvgPriceFullyScale, "openAvgPriceFullyScale")
                ?? .stream(position.openAvgPrice, "openAvgPrice"),
            averageClosePrice: try .stream(position.closeAvgPrice, "closeAvgPrice"),
            liquidationPrice: try .streamIfPresent(position.liquidatePrice, "liquidatePrice"),
            initialMargin: try .stream(position.im, "im"),
            originalInitialMargin: try .stream(position.oim, "oim"),
            funding: try .stream(position.holdFee, "holdFee"),
            realizedProfit: try .stream(position.realised, "realised"),
            // MEXC's `.proto` says to check whether the flag is there; it is off when it isn't.
            addsMarginAutomatically: position.hasAutoAddIm && position.autoAddIm,
            unrealizedProfit: try .streamIfPresent(position.pnl, "pnl"),
            closingProfit: try .streamIfPresent(position.closeProfitLoss, "closeProfitLoss"),
            profitRatio: nil,
            marginRatio: try .streamIfPresent(position.marginRatio, "marginRatio"),
            fee: try .streamIfPresent(position.fee, "fee"),
            totalFee: nil,
            autoDeleveragingLevel: position.hasAdlLevel ? Int(position.adlLevel) : nil,
            createdAt: Date(milliseconds: try required(position.hasCreateTime, position.createTime, "createTime")),
            updatedAt: position.hasUpdateTime ? Date(milliseconds: position.updateTime) : nil
        )
    }
}

extension MexcFutures.BalanceUpdate {
    fileprivate init(_ balance: AssetChange) throws {
        self.init(
            asset: try required(balance.currency, "currency"),
            available: try .stream(balance.availableBalance, "availableBalance"),
            frozen: try .stream(balance.frozenBalance, "frozenBalance"),
            positionMargin: try .stream(balance.positionMargin, "positionMargin"),
            bonus: try .streamIfPresent(balance.bonus, "bonus")
        )
    }
}

/// A string Protobuf sends, which a missing value leaves empty.
private func required(_ text: String, _ field: String) throws -> String {
    guard !text.isEmpty else { throw DecodingError.missing(field) }
    return text
}

/// A number Protobuf sends without `optional`, which a missing value leaves 0.
private func requiredNonZero<Number: BinaryInteger>(_ number: Number, _ field: String) throws -> Int {
    guard number != 0 else { throw DecodingError.missing(field) }
    return Int(number)
}

/// A value Protobuf marks `optional`, which must be there.
private func required<Value>(_ isPresent: Bool, _ value: Value, _ field: String) throws -> Value {
    guard isPresent else { throw DecodingError.missing(field) }
    return value
}

extension DecodingError {
    fileprivate static func missing(_ field: String) -> Self {
        .dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "A push is missing its \(field)"))
    }
}

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
