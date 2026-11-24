import Foundation
import MexcKitProtobuf

/// The account streams of ``StreamEndpoints``, on its logged-in connection.
///
/// MEXC's `personal.filter` names nine of the account's channels, from orders to risk limits. While
/// only streams of those are open, the connection asks for just their channels and markets. MEXC's
/// documentation doesn't say whether its other account channels, such as trailing orders or
/// liquidation risk, are pushed while a filter is in place, so while a stream of one of them is open,
/// the connection sends an empty filter, which MEXC documents as restoring its pushes, and each
/// stream drops what isn't its own.
extension StreamEndpoints {
    // MARK: - Endpoints

    func orders(_ symbols: Set<MexcFutures.Symbol>) -> AsyncThrowingStream<MexcFutures.Order, any Error> {
        accountStream("orders", channel: "order", filterKey: "order", markets: symbols) { push in
            guard case .orderChange(let order) = push.data else { return nil }
            return (order.symbol, { try MexcFutures.Order(order) })
        }
    }

    func fills(_ symbols: Set<MexcFutures.Symbol>) -> AsyncThrowingStream<MexcFutures.Fill, any Error> {
        accountStream("fills", channel: "order.deal", filterKey: "order.deal", markets: symbols) { push in
            guard case .orderDealDetail(let fill) = push.data else { return nil }
            return (fill.symbol, { try MexcFutures.Fill(fill) })
        }
    }

    func positions(_ symbols: Set<MexcFutures.Symbol>) -> AsyncThrowingStream<MexcFutures.Position, any Error> {
        accountStream("positions", channel: "position", filterKey: "position", markets: symbols) { push in
            guard case .positionChange(let position) = push.data else { return nil }
            return (position.symbol, { try MexcFutures.Position(position) })
        }
    }

    func balances() -> AsyncThrowingStream<MexcFutures.BalanceUpdate, any Error> {
        accountStream("balances", channel: "asset", filterKey: "asset", markets: []) { push in
            guard case .assetChange(let balance) = push.data else { return nil }
            return (nil, { try MexcFutures.BalanceUpdate(balance) })
        }
    }

    func planOrders(_ symbols: Set<MexcFutures.Symbol>) -> AsyncThrowingStream<MexcFutures.PlanOrder, any Error> {
        accountStream("plan orders", channel: "plan.order", filterKey: "plan.order", markets: symbols) { push in
            guard case .contractPlanOrder(let plan) = push.data else { return nil }
            return (plan.symbol, { try MexcFutures.PlanOrder(plan) })
        }
    }

    func stopOrders(_ symbols: Set<MexcFutures.Symbol>) -> AsyncThrowingStream<MexcFutures.StopOrder, any Error> {
        accountStream("stop orders", channel: "stop.planorder", filterKey: "stop.planorder", markets: symbols) { push in
            guard case .contractStopPlanOrder(let stop) = push.data else { return nil }
            return (stop.symbol, { try MexcFutures.StopOrder(stop) })
        }
    }

    func attachedStops(
        _ symbols: Set<MexcFutures.Symbol>
    ) -> AsyncThrowingStream<MexcFutures.AttachedStopsUpdate, any Error> {
        accountStream("attached stops", channel: "stop.order", filterKey: "stop.order", markets: symbols) { push in
            guard case .contractStopOrder(let stops) = push.data else { return nil }
            return (stops.symbol, { try MexcFutures.AttachedStopsUpdate(stops) })
        }
    }

    func trailingOrders(
        _ symbols: Set<MexcFutures.Symbol>
    ) -> AsyncThrowingStream<MexcFutures.TrailingOrder, any Error> {
        accountStream("trailing orders", channel: "track.order", filterKey: nil, markets: symbols) { push in
            guard case .contractTrackOrder(let trailing) = push.data else { return nil }
            return (trailing.symbol, { try MexcFutures.TrailingOrder(trailing) })
        }
    }

    func riskLimits(
        _ symbols: Set<MexcFutures.Symbol>
    ) -> AsyncThrowingStream<MexcFutures.PositionRiskLimit, any Error> {
        accountStream("risk limits", channel: "risk.limit", filterKey: "risk.limit", markets: symbols) { push in
            guard case .contractUserRiskLimit(let limit) = push.data else { return nil }
            return (limit.symbol, { try MexcFutures.PositionRiskLimit(limit) })
        }
    }

    func liquidationRisks(
        _ symbols: Set<MexcFutures.Symbol>
    ) -> AsyncThrowingStream<MexcFutures.LiquidationRisk, any Error> {
        accountStream("liquidation risks", channel: "liquidate.risk", filterKey: nil, markets: symbols) { push in
            guard case .liquidateRiskChange(let risk) = push.data else { return nil }
            return (risk.symbol, { try MexcFutures.LiquidationRisk(risk) })
        }
    }

    func liquidationNotices() -> AsyncThrowingStream<MexcFutures.LiquidationNotice, any Error> {
        accountStream("liquidation notices", channel: "generic.notify", filterKey: nil, markets: []) { push in
            // MEXC's generic notices of type 1 are liquidation notices, the only type it documents.
            guard case .notifyGeneric(let notice) = push.data, notice.type == 1 else { return nil }
            return (nil, { try MexcFutures.LiquidationNotice(try required(notice.hasParam, notice.param, "param")) })
        }
    }

    func chaseFailures(_ symbols: Set<MexcFutures.Symbol>) -> AsyncThrowingStream<MexcFutures.ChaseFailure, any Error> {
        accountStream("chase failures", channel: "order.chase", filterKey: nil, markets: symbols) { push in
            guard case .orderChase(let failure) = push.data else { return nil }
            return (failure.s, { try MexcFutures.ChaseFailure(failure) })
        }
    }

    func positionModes() -> AsyncThrowingStream<MexcFutures.PositionMode, any Error> {
        accountStream("position modes", channel: "position.mode", filterKey: nil, markets: []) { push in
            guard case .positionModeResult(let result) = push.data else { return nil }
            return (nil, { MexcFutures.PositionMode(rawValue: try requiredNonZero(result.positionMode, "positionMode")) })
        }
    }

    func leverageModes() -> AsyncThrowingStream<MexcFutures.LeverageMode, any Error> {
        accountStream("leverage modes", channel: "leverage.mode", filterKey: nil, markets: []) { push in
            // -1 is MEXC's value when the account has no leverage mode set, which isn't a change.
            guard case .leverageMode(let mode) = push.data, mode.lm != -1 else { return nil }
            return (nil, { MexcFutures.LeverageMode(rawValue: Int(try required(mode.hasLm, mode.lm, "lm"))) })
        }
    }

    func trialBonuses() -> AsyncThrowingStream<MexcFutures.TrialBonusUpdate, any Error> {
        accountStream("trial bonuses", channel: "bonus", filterKey: nil, markets: []) { push in
            guard case .bonusNotify(let bonus) = push.data else { return nil }
            return (nil, { try MexcFutures.TrialBonusUpdate(bonus) })
        }
    }

    /// An account stream of the pushes of `push.personal.<channel>`.
    ///
    /// `filterKey` is the channel's key in MEXC's `personal.filter`, `nil` for a channel it doesn't
    /// name. `value` gives a
    /// push's market, `nil` for one of the whole account, and how to read it; it returns `nil` for a
    /// push the stream doesn't take. A push of another market than `markets` is dropped before it is
    /// read, so it can't end this stream: MEXC's filter names the markets of every stream of the
    /// channel, and channels without a filter key push every market.
    private func accountStream<Element: Sendable>(
        _ name: String, channel: String, filterKey: String?, markets: Set<MexcFutures.Symbol>,
        value: @escaping @Sendable (ContractWrapper) -> (market: String?, read: () throws -> Element)?
    ) -> AsyncThrowingStream<Element, any Error> {
        let subscription = StreamSubscription(
            name: "the account's \(name)", channel: "personal.\(channel)", filter: filterKey
        )
        return stream(subscription, on: accountConnection, markets: markets, buffering: .unbounded) { push in
            guard let (market, read) = value(push) else { return [] }
            if let market, !markets.isEmpty, !markets.contains(MexcFutures.Symbol(rawValue: market)) { return [] }
            return [try read()]
        }
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
            order: fill.orderID.isEmpty ? nil : MexcFutures.OrderID(rawValue: fill.orderID),
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
            trialBonus: try .streamIfPresent(balance.bonus, "bonus")
        )
    }
}

extension MexcFutures.PlanOrder {
    fileprivate init(_ plan: ContractPlanOrder) throws {
        self.init(
            id: MexcFutures.PlanOrderID(rawValue: try required(plan.id, "id")),
            symbol: MexcFutures.Symbol(rawValue: try required(plan.symbol, "symbol")),
            side: MexcFutures.OrderSide(rawValue: try requiredNonZero(plan.side, "side")),
            type: MexcFutures.OrderType(rawValue: try requiredNonZero(plan.orderType, "orderType")),
            marginMode: MexcFutures.MarginMode(rawValue: Int(try required(plan.hasOpenType, plan.openType, "openType"))),
            leverage: Int(try required(plan.hasLeverage, plan.leverage, "leverage")),
            trigger: MexcFutures.Trigger(
                price: try .stream(plan.triggerPrice, "triggerPrice"),
                condition: MexcFutures.TriggerCondition(rawValue: try requiredNonZero(plan.triggerType, "triggerType")),
                source: MexcFutures.PriceSource(rawValue: try requiredNonZero(plan.trend, "trend"))
            ),
            price: try .streamIfPresent(plan.price, "price"),
            volume: try .stream(plan.vol, "vol"),
            state: MexcFutures.PlanOrderState(rawValue: try requiredNonZero(plan.state, "state")),
            // In hours, as in REST.
            lifetime: .seconds(Int(try required(plan.hasExecuteCycle, plan.executeCycle, "executeCycle")) * 3600),
            takeProfit: try .stream(price: plan.takeProfitPrice, source: plan.profitTrend, "takeProfitPrice"),
            stopLoss: try .stream(price: plan.stopLossPrice, source: plan.lossTrend, "stopLossPrice"),
            order: optionalID(plan.orderID).map(MexcFutures.OrderID.init(rawValue:)),
            errorCode: plan.errorCode == 0 ? nil : MexcError.Code(rawValue: Int(plan.errorCode)),
            positionMode: plan.positionMode == 0 ? nil : MexcFutures.PositionMode(rawValue: Int(plan.positionMode)),
            reduceOnly: plan.reduceOnly,
            triggerProtection: nil,
            createdAt: try .stream(plan.createTime, "createTime"),
            updatedAt: .streamIfPresent(plan.updateTime)
        )
    }
}

extension MexcFutures.StopOrder {
    fileprivate init(_ stop: ContractStopPlanOrder) throws {
        let takeProfit = try MexcFutures.AttachedStop.stream(
            price: stop.takeProfitPrice, source: stop.profitTrend, "takeProfitPrice"
        )
        let stopLoss = try MexcFutures.AttachedStop.stream(price: stop.stopLossPrice, source: stop.lossTrend, "stopLossPrice")
        // Type 1 is a limit order at the order price, as in REST. The push has no take-profit type.
        let stopLossLimitPrice = stop.stopLossType == 1
            ? try Decimal.streamIfPresent(stop.stopLossOrderPrice, "stopLossOrderPrice") : nil
        self.init(
            id: MexcFutures.StopOrderID(rawValue: String(try requiredNonZero(stop.id, "id"))),
            symbol: MexcFutures.Symbol(rawValue: try required(stop.symbol, "symbol")),
            position: optionalID(stop.positionID).map(MexcFutures.PositionID.init(rawValue:)),
            side: MexcFutures.PositionSide(rawValue: try requiredNonZero(stop.positionType, "positionType")),
            order: optionalID(stop.orderID).map(MexcFutures.OrderID.init(rawValue:)),
            takeProfit: takeProfit.map { Exit(price: $0.price, source: $0.source) },
            stopLoss: stopLoss.map { Exit(price: $0.price, source: $0.source, limitPrice: stopLossLimitPrice) },
            volume: try .stream(stop.vol, "vol"),
            state: MexcFutures.PlanOrderState(rawValue: try requiredNonZero(stop.state, "state")),
            // Missing reads 0, which isn't finished.
            isFinished: stop.isFinished == 1,
            triggered: stop.triggerSide == 0 ? nil : Leg(rawValue: Int(stop.triggerSide)),
            placedVolume: try .streamIfPresent(stop.realityVol, "realityVol"),
            placedOrder: optionalID(stop.placeOrderID).map(MexcFutures.OrderID.init(rawValue:)),
            errorCode: stop.errorCode == 0 ? nil : MexcError.Code(rawValue: Int(stop.errorCode)),
            triggerProtection: nil,
            createdAt: try .stream(stop.createTime, "createTime"),
            updatedAt: .streamIfPresent(stop.updateTime)
        )
    }
}

extension MexcFutures.AttachedStopsUpdate {
    fileprivate init(_ stops: ContractStopOrder) throws {
        self.init(
            order: MexcFutures.OrderID(rawValue: try required(stops.orderID, "orderId")),
            symbol: MexcFutures.Symbol(rawValue: try required(stops.symbol, "symbol")),
            takeProfit: try .stream(price: stops.takeProfitPrice, source: stops.profitTrend, "takeProfitPrice"),
            stopLoss: try .stream(price: stops.stopLossPrice, source: stops.lossTrend, "stopLossPrice")
        )
    }
}

extension MexcFutures.AttachedStop {
    /// A take-profit or stop-loss: `nil` when its price is missing or 0, and watching the last price
    /// unless `source` says otherwise, as in REST.
    fileprivate static func stream(price: String, source: Int32, _ field: String) throws -> Self? {
        guard let price = try Decimal.streamIfPresent(price, field), price != 0 else { return nil }
        return Self(price: price, source: source == 0 ? .last : MexcFutures.PriceSource(rawValue: Int(source)))
    }
}

extension MexcFutures.TrailingOrder {
    fileprivate init(_ trailing: ContractTrackOrder) throws {
        self.init(
            id: MexcFutures.TrailingOrderID(rawValue: try required(trailing.id, "id")),
            symbol: MexcFutures.Symbol(rawValue: try required(trailing.symbol, "symbol")),
            side: MexcFutures.OrderSide(rawValue: try requiredNonZero(trailing.side, "side")),
            marginMode: MexcFutures.MarginMode(rawValue: Int(try required(trailing.hasOpenType, trailing.openType, "openType"))),
            leverage: Int(try required(trailing.hasLeverage, trailing.leverage, "leverage")),
            volume: try .stream(trailing.vol, "vol"),
            source: MexcFutures.PriceSource(rawValue: try requiredNonZero(trailing.trend, "trend")),
            callback: Callback(
                kind: Callback.Kind(rawValue: try requiredNonZero(trailing.backType, "backType")),
                value: try .stream(trailing.backValue, "backValue")
            ),
            activationPrice: try Decimal.streamIfPresent(trailing.activePrice, "activePrice").flatMap { $0 == 0 ? nil : $0 },
            referencePrice: try .streamIfPresent(trailing.markPrice, "markPrice"),
            triggerPrice: try .streamIfPresent(trailing.triggerPrice, "triggerPrice"),
            triggerCondition: trailing.triggerType == 0 ? nil : MexcFutures.TriggerCondition(rawValue: Int(trailing.triggerType)),
            // 0 is a state here: not yet active.
            state: MexcFutures.TrailingOrderState(rawValue: Int(trailing.state)),
            order: trailing.orderID == 0 ? nil : MexcFutures.OrderID(rawValue: String(trailing.orderID)),
            errorCode: trailing.errorCode == 0 ? nil : MexcError.Code(rawValue: Int(trailing.errorCode)),
            positionMode: trailing.positionMode == 0 ? nil : MexcFutures.PositionMode(rawValue: Int(trailing.positionMode)),
            reduceOnly: trailing.reduceOnly,
            createdAt: try .stream(trailing.createTime, "createTime"),
            updatedAt: .streamIfPresent(trailing.updateTime)
        )
    }
}

extension MexcFutures.PositionRiskLimit {
    fileprivate init(_ limit: ContractUserRiskLimit) throws {
        self.init(
            symbol: MexcFutures.Symbol(rawValue: try required(limit.symbol, "symbol")),
            side: MexcFutures.PositionSide(rawValue: try requiredNonZero(limit.positionType, "positionType")),
            marginMode: limit.openType == 0 ? nil : MexcFutures.MarginMode(rawValue: Int(limit.openType)),
            limit: MexcFutures.Contract.RiskLimit(
                level: Int(try required(limit.hasLevel, limit.level, "level")),
                maximumVolume: try .stream(limit.maxVol, "maxVol"),
                maintenanceMarginRate: try .stream(limit.mmr, "mmr"),
                initialMarginRate: try .stream(limit.imr, "imr"),
                maximumLeverage: Int(try required(limit.hasMaxLeverage, limit.maxLeverage, "maxLeverage"))
            )
        )
    }
}

extension MexcFutures.LiquidationRisk {
    fileprivate init(_ risk: LiquidateRiskChange) throws {
        self.init(
            symbol: MexcFutures.Symbol(rawValue: try required(risk.symbol, "symbol")),
            position: risk.hasPositionID && risk.positionID != 0 ? MexcFutures.PositionID(rawValue: String(risk.positionID)) : nil,
            liquidationPrice: try .streamIfPresent(risk.liquidatePrice, "liquidatePrice"),
            marginRatio: try .streamIfPresent(risk.marginRatio, "marginRatio"),
            autoDeleveragingLevel: risk.adlLevel == 0 ? nil : Int(risk.adlLevel)
        )
    }
}

extension MexcFutures.LiquidationNotice {
    fileprivate init(_ notice: Liquidate) throws {
        self.init(
            kind: Kind(rawValue: try requiredNonZero(notice.notifyType, "notifyType")),
            marginMode: MexcFutures.MarginMode(rawValue: try requiredNonZero(notice.openType, "openType")),
            marketName: notice.dne.isEmpty ? nil : notice.dne,
            isMultiAssetMode: notice.multiAssets,
            marginRatio: try .streamIfPresent(notice.marginRate, "marginRate")
        )
    }
}

extension MexcFutures.ChaseFailure {
    fileprivate init(_ failure: OrderChase) throws {
        self.init(
            symbol: MexcFutures.Symbol(rawValue: try required(failure.s, "s")),
            errorCode: MexcError.Code(rawValue: try requiredNonZero(failure.ec, "ec"))
        )
    }
}

extension MexcFutures.TrialBonusUpdate {
    fileprivate init(_ bonus: BonusNotify) throws {
        self.init(
            asset: try required(bonus.c, "c"),
            amount: try .streamIfPresent(bonus.b, "b"),
            expiresAt: .streamIfPresent(bonus.be),
            isGranted: bonus.g,
            nearestExpiry: .streamIfPresent(bonus.ret),
            nearestExpiringAmount: try .streamIfPresent(bonus.rea, "rea")
        )
    }
}
