public import Foundation

// MARK: - Protocol

extension MexcFutures {
    /// Live market and account data, pushed by MEXC over a WebSocket as it changes.
    ///
    /// The market streams need no credentials and share one connection. The account streams, from
    /// ``orders(_:)`` on, need the client's credentials and share a second connection, which logs in
    /// when the first of them starts and closes when the last one ends; without credentials they
    /// throw ``ClientError/Reason/missingCredentials``. Streams of the same values share one
    /// subscription. A stream subscribes as soon as it's
    /// made, and unsubscribes when it ends: when the task iterating it is cancelled, or when the
    /// stream is released, such as after a `break` out of a loop over it. The connection closes when
    /// the last stream ends.
    ///
    /// A stream throws ``ClientError`` when:
    /// - MEXC rejects the subscription, such as for an unknown symbol:
    ///   ``ClientError/Reason/subscriptionRejected``;
    /// - MEXC rejects the login of the account streams: ``ClientError/Reason/loginRejected``. This
    ///   also ends account streams already running when it happens on a reconnect, as does an error
    ///   the credentials provider throws, which ends them unchanged;
    /// - MEXC doesn't acknowledge the subscription or the login within 10 seconds:
    ///   ``ClientError/Reason/acknowledgementTimedOut``. The connection then starts over, and streams
    ///   MEXC had acknowledged before subscribe again;
    /// - connecting fails before MEXC ever acknowledged the subscription:
    ///   ``ClientError/Reason/connectionFailed``, including when it doesn't open within 10 seconds;
    /// - a stream of the same market is open with values MEXC's pushes can't tell apart, such as
    ///   order books with another `step`: ``ClientError/Reason/invalidRequest``. The methods that
    ///   can throw it say so.
    ///
    /// A push whose values don't decode, such as a price that isn't a number, ends the stream with
    /// `DecodingError`. One bad market in ``tickers()`` ends that stream for every market, as one bad
    /// element fails the REST ``MarketAPI/tickers()``.
    ///
    /// When an open connection drops, the client reconnects on its own, waiting 1 second and then
    /// twice as long after each failure, up to 60 seconds, and subscribes again. Pushes sent while it
    /// was disconnected are lost, so read the REST endpoints again when continuity matters.
    public protocol StreamAPI: Sendable {
        /// The market's latest prices and statistics, about once a second while it trades.
        ///
        /// A consumer that falls behind gets the latest ticker only.
        func ticker(_ symbol: Symbol) -> AsyncThrowingStream<Ticker, any Error>

        /// The prices and statistics of every market, about every 2 seconds.
        ///
        /// A consumer that falls behind gets the latest summaries only.
        func tickers() -> AsyncThrowingStream<[TickerSummary], any Error>

        /// The market's trades, as they happen.
        ///
        /// With `merged`, MEXC sends at most one trade for each short period, without its ID, as it
        /// does by default. Without it, MEXC sends every trade with its ID. Every trade reaches a
        /// consumer that falls behind.
        ///
        /// MEXC's pushes don't say which kind they are, so a market's merged and unmerged deals can't
        /// be streamed at once: the second throws ``ClientError/Reason/invalidRequest`` while the
        /// first is open.
        func deals(_ symbol: Symbol, merged: Bool) -> AsyncThrowingStream<Deal, any Error>

        /// Changes to the market's order book, every 200 milliseconds while it changes.
        ///
        /// A level's volume is its new total, and a volume of 0 removes it. Each change's
        /// ``OrderBook/Change/version`` is one more than the previous one's; a gap means changes were
        /// lost, during a reconnect or on MEXC's side, which happens now and then. Every change reaches a consumer that falls behind.
        /// ``OrderBookSync`` keeps a whole book from these changes.
        func orderBookChanges(_ symbol: Symbol) -> AsyncThrowingStream<OrderBook.Change, any Error>

        /// The market's order book with `limit` levels a side, each time it changes.
        ///
        /// MEXC accepts a `limit` of 5, 10 or 20; another throws ``ClientError/Reason/invalidRequest``.
        /// A consumer that falls behind gets the latest order book only.
        ///
        /// MEXC's pushes don't say their limit, so a market's order books can be streamed with one
        /// `limit` at a time: another throws ``ClientError/Reason/invalidRequest`` while the first is
        /// open.
        func orderBooks(_ symbol: Symbol, limit: Int) -> AsyncThrowingStream<OrderBook, any Error>

        /// The market's order book with prices grouped into steps of `step`, every 200 milliseconds.
        ///
        /// A `step` of 10 groups the levels at prices such as 100010, 100020 and 100030. A consumer
        /// that falls behind gets the latest order book only.
        ///
        /// MEXC's pushes don't say their step, so a market's order books can be grouped by one `step`
        /// at a time: another throws ``ClientError/Reason/invalidRequest`` while the first is open.
        func orderBooks(_ symbol: Symbol, step: Decimal) -> AsyncThrowingStream<OrderBook, any Error>

        /// The market's current candle of the last traded price, each time it changes.
        ///
        /// A consumer that falls behind gets the latest candle only.
        func candles(_ symbol: Symbol, interval: Candle.Interval) -> AsyncThrowingStream<Candle, any Error>

        /// The market's index price, each time it changes.
        ///
        /// A consumer that falls behind gets the latest price only.
        func indexPrice(_ symbol: Symbol) -> AsyncThrowingStream<PriceSnapshot, any Error>

        /// The market's fair price, each time it changes.
        ///
        /// A consumer that falls behind gets the latest price only.
        func fairPrice(_ symbol: Symbol) -> AsyncThrowingStream<PriceSnapshot, any Error>

        /// The account's orders on the given markets, or on every market for an empty set, each
        /// time one changes.
        ///
        /// MEXC's push leaves out the attached stops, the total fee and trigger protection, so they
        /// are `nil`; read the order through ``OrderAPI`` for them. Every change reaches a consumer
        /// that falls behind.
        func orders(_ symbols: Set<Symbol>) -> AsyncThrowingStream<Order, any Error>

        /// The account's fills on the given markets, or on every market for an empty set, as they
        /// happen. Every fill reaches a consumer that falls behind.
        func fills(_ symbols: Set<Symbol>) -> AsyncThrowingStream<Fill, any Error>

        /// The account's positions on the given markets, or on every market for an empty set, each
        /// time one changes.
        ///
        /// MEXC's push leaves out the profit ratio and the total fee, so they are `nil`, and
        /// ``Position/addsMarginAutomatically`` is `false` when the push leaves the flag out. Every
        /// change reaches a consumer that falls behind.
        func positions(_ symbols: Set<Symbol>) -> AsyncThrowingStream<Position, any Error>

        /// The futures account's balances, each time one changes. Every change reaches a consumer
        /// that falls behind.
        func balances() -> AsyncThrowingStream<BalanceUpdate, any Error>

        /// The account's plan orders on the given markets, or on every market for an empty set, each
        /// time one changes.
        ///
        /// MEXC's push leaves out trigger protection, so it is `nil`. Every change reaches a consumer
        /// that falls behind.
        func planOrders(_ symbols: Set<Symbol>) -> AsyncThrowingStream<PlanOrder, any Error>

        /// The account's stop orders on the given markets, or on every market for an empty set, each
        /// time one changes.
        ///
        /// MEXC's push leaves out trigger protection, so it is `nil`, and doesn't say how a
        /// take-profit closes, so its ``StopOrder/Exit/limitPrice`` is `nil` even when it closes with
        /// a limit order; read the stop order through ``StopOrderAPI`` for them. Every change
        /// reaches a consumer that falls behind.
        func stopOrders(_ symbols: Set<Symbol>) -> AsyncThrowingStream<StopOrder, any Error>

        /// The take-profit and stop-loss prices of the account's orders on the given markets, or on
        /// every market for an empty set, each time they change. Every change reaches a consumer that
        /// falls behind.
        func attachedStops(_ symbols: Set<Symbol>) -> AsyncThrowingStream<AttachedStopsUpdate, any Error>

        /// The account's trailing orders on the given markets, or on every market for an empty set,
        /// each time one changes. Every change reaches a consumer that falls behind.
        func trailingOrders(_ symbols: Set<Symbol>) -> AsyncThrowingStream<TrailingOrder, any Error>

        /// The account's risk limit tiers on the given markets, or on every market for an empty set,
        /// each time one changes.
        ///
        /// The tier's maximum leverage is as MEXC sends it, which can be -1, MEXC's value when none is
        /// set. Every change reaches a consumer that falls behind.
        func riskLimits(_ symbols: Set<Symbol>) -> AsyncThrowingStream<PositionRiskLimit, any Error>

        /// How close the account's positions on the given markets, or on every market for an empty
        /// set, are to liquidation, each time that changes. Every change reaches a consumer that
        /// falls behind.
        func liquidationRisks(_ symbols: Set<Symbol>) -> AsyncThrowingStream<LiquidationRisk, any Error>

        /// MEXC's notices that one of the account's positions was liquidated or is close to it. Every
        /// notice reaches a consumer that falls behind.
        func liquidationNotices() -> AsyncThrowingStream<LiquidationNotice, any Error>

        /// MEXC's reports that chasing one of the account's orders on the given markets, or on every
        /// market for an empty set, failed. Every report reaches a consumer that falls behind.
        func chaseFailures(_ symbols: Set<Symbol>) -> AsyncThrowingStream<ChaseFailure, any Error>

        /// The account's position mode, each time it changes. Every change reaches a consumer that
        /// falls behind.
        func positionModes() -> AsyncThrowingStream<PositionMode, any Error>

        /// The account's leverage mode, each time it changes.
        ///
        /// A push of -1, MEXC's value when no mode is set, isn't streamed. Every change reaches a
        /// consumer that falls behind.
        func leverageModes() -> AsyncThrowingStream<LeverageMode, any Error>

        /// The account's trial bonus, each time it changes. Every change reaches a consumer that falls
        /// behind.
        func trialBonuses() -> AsyncThrowingStream<TrialBonusUpdate, any Error>
    }
}

// MARK: - Defaults

extension MexcFutures.StreamAPI {
    /// The account's orders on every market, each time one changes.
    public func orders() -> AsyncThrowingStream<MexcFutures.Order, any Error> {
        orders([])
    }

    /// The account's fills on every market, as they happen.
    public func fills() -> AsyncThrowingStream<MexcFutures.Fill, any Error> {
        fills([])
    }

    /// The account's positions on every market, each time one changes.
    public func positions() -> AsyncThrowingStream<MexcFutures.Position, any Error> {
        positions([])
    }

    /// The account's plan orders on every market, each time one changes.
    public func planOrders() -> AsyncThrowingStream<MexcFutures.PlanOrder, any Error> {
        planOrders([])
    }

    /// The account's stop orders on every market, each time one changes.
    public func stopOrders() -> AsyncThrowingStream<MexcFutures.StopOrder, any Error> {
        stopOrders([])
    }

    /// The take-profit and stop-loss prices of the account's orders on every market, each time they
    /// change.
    public func attachedStops() -> AsyncThrowingStream<MexcFutures.AttachedStopsUpdate, any Error> {
        attachedStops([])
    }

    /// The account's trailing orders on every market, each time one changes.
    public func trailingOrders() -> AsyncThrowingStream<MexcFutures.TrailingOrder, any Error> {
        trailingOrders([])
    }

    /// The account's risk limit tiers on every market, each time one changes.
    public func riskLimits() -> AsyncThrowingStream<MexcFutures.PositionRiskLimit, any Error> {
        riskLimits([])
    }

    /// How close the account's positions on every market are to liquidation, each time that changes.
    public func liquidationRisks() -> AsyncThrowingStream<MexcFutures.LiquidationRisk, any Error> {
        liquidationRisks([])
    }

    /// MEXC's reports that chasing one of the account's orders on any market failed.
    public func chaseFailures() -> AsyncThrowingStream<MexcFutures.ChaseFailure, any Error> {
        chaseFailures([])
    }
}
