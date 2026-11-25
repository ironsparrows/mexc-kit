import Foundation

/// The live ``MexcFutures/StreamAPI``: the market streams come from ``MarketStreams`` on the public
/// connection, and the account streams from ``AccountStreams`` on the logged-in one.
struct Streams: MexcFutures.StreamAPI {
    let market: MarketStreams
    let account: AccountStreams

    // MARK: Market

    func ticker(_ symbol: MexcFutures.Symbol) -> AsyncThrowingStream<MexcFutures.Ticker, any Error> {
        market.ticker(symbol)
    }

    func tickers() -> AsyncThrowingStream<[MexcFutures.TickerSummary], any Error> {
        market.tickers()
    }

    func deals(_ symbol: MexcFutures.Symbol, merged: Bool) -> AsyncThrowingStream<MexcFutures.Deal, any Error> {
        market.deals(symbol, merged: merged)
    }

    func orderBookChanges(
        _ symbol: MexcFutures.Symbol
    ) -> AsyncThrowingStream<MexcFutures.OrderBook.Change, any Error> {
        market.orderBookChanges(symbol)
    }

    func orderBooks(_ symbol: MexcFutures.Symbol, limit: Int) -> AsyncThrowingStream<MexcFutures.OrderBook, any Error> {
        market.orderBooks(symbol, limit: limit)
    }

    func orderBooks(
        _ symbol: MexcFutures.Symbol, step: Decimal
    ) -> AsyncThrowingStream<MexcFutures.OrderBook, any Error> {
        market.orderBooks(symbol, step: step)
    }

    func candles(
        _ symbol: MexcFutures.Symbol, interval: MexcFutures.Candle.Interval
    ) -> AsyncThrowingStream<MexcFutures.Candle, any Error> {
        market.candles(symbol, interval: interval)
    }

    func indexPrice(_ symbol: MexcFutures.Symbol) -> AsyncThrowingStream<MexcFutures.PriceSnapshot, any Error> {
        market.indexPrice(symbol)
    }

    func fairPrice(_ symbol: MexcFutures.Symbol) -> AsyncThrowingStream<MexcFutures.PriceSnapshot, any Error> {
        market.fairPrice(symbol)
    }

    // MARK: Account

    func orders(_ symbols: Set<MexcFutures.Symbol>) -> AsyncThrowingStream<MexcFutures.Order, any Error> {
        account.orders(symbols)
    }

    func fills(_ symbols: Set<MexcFutures.Symbol>) -> AsyncThrowingStream<MexcFutures.Fill, any Error> {
        account.fills(symbols)
    }

    func positions(_ symbols: Set<MexcFutures.Symbol>) -> AsyncThrowingStream<MexcFutures.Position, any Error> {
        account.positions(symbols)
    }

    func balances() -> AsyncThrowingStream<MexcFutures.BalanceUpdate, any Error> {
        account.balances()
    }

    func planOrders(_ symbols: Set<MexcFutures.Symbol>) -> AsyncThrowingStream<MexcFutures.PlanOrder, any Error> {
        account.planOrders(symbols)
    }

    func stopOrders(_ symbols: Set<MexcFutures.Symbol>) -> AsyncThrowingStream<MexcFutures.StopOrder, any Error> {
        account.stopOrders(symbols)
    }

    func attachedStops(
        _ symbols: Set<MexcFutures.Symbol>
    ) -> AsyncThrowingStream<MexcFutures.AttachedStopsUpdate, any Error> {
        account.attachedStops(symbols)
    }

    func trailingOrders(
        _ symbols: Set<MexcFutures.Symbol>
    ) -> AsyncThrowingStream<MexcFutures.TrailingOrder, any Error> {
        account.trailingOrders(symbols)
    }

    func riskLimits(
        _ symbols: Set<MexcFutures.Symbol>
    ) -> AsyncThrowingStream<MexcFutures.PositionRiskLimit, any Error> {
        account.riskLimits(symbols)
    }

    func liquidationRisks(
        _ symbols: Set<MexcFutures.Symbol>
    ) -> AsyncThrowingStream<MexcFutures.LiquidationRisk, any Error> {
        account.liquidationRisks(symbols)
    }

    func liquidationNotices() -> AsyncThrowingStream<MexcFutures.LiquidationNotice, any Error> {
        account.liquidationNotices()
    }

    func chaseFailures(_ symbols: Set<MexcFutures.Symbol>) -> AsyncThrowingStream<MexcFutures.ChaseFailure, any Error> {
        account.chaseFailures(symbols)
    }

    func positionModes() -> AsyncThrowingStream<MexcFutures.PositionMode, any Error> {
        account.positionModes()
    }

    func leverageModes() -> AsyncThrowingStream<MexcFutures.LeverageMode, any Error> {
        account.leverageModes()
    }

    func trialBonuses() -> AsyncThrowingStream<MexcFutures.TrialBonusUpdate, any Error> {
        account.trialBonuses()
    }
}
