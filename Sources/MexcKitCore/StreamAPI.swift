public import Foundation

// MARK: - Protocol

extension MexcFutures {
    /// Live market data, pushed by MEXC over a WebSocket as it changes.
    ///
    /// None of these streams needs credentials. Every stream of one client shares one connection,
    /// and streams of the same values share one subscription. A stream subscribes as soon as it's
    /// made, and unsubscribes when it ends: when the task iterating it is cancelled, or when the
    /// stream is released, such as after a `break` out of a loop over it. The connection closes when
    /// the last stream ends.
    ///
    /// A stream throws ``ClientError`` when:
    /// - MEXC rejects the subscription, such as for an unknown symbol:
    ///   ``ClientError/Reason/subscriptionRejected``;
    /// - MEXC doesn't acknowledge it within 10 seconds: ``ClientError/Reason/acknowledgementTimedOut``;
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
        /// lost, such as during a reconnect. Every change reaches a consumer that falls behind.
        func orderBookChanges(_ symbol: Symbol) -> AsyncThrowingStream<OrderBook.Change, any Error>

        /// The market's order book with `limit` levels a side, each time it changes.
        ///
        /// MEXC accepts a `limit` of 5, 10 or 20. A consumer that falls behind gets the latest order
        /// book only.
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
    }
}
