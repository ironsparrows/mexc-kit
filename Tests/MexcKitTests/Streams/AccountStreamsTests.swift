import Foundation
import MexcKitProtobuf
import SwiftProtobuf
import Testing

@testable import MexcKit

extension MexcKitTests {
    /// The account streams over a fake server: login, the `personal.filter` union, markets kept per
    /// stream, and each push mapped to its model.
    ///
    /// No private push has been recorded yet, so the pushes here are built from the examples on MEXC's
    /// WebSocket documentation pages (order, fill details, position, assets) with the `.proto` messages.
    @Suite("Account streams", .timeLimit(.minutes(1)))
    struct AccountStreamsTests {
        private let server = FakeWebSocketServer()

        // MARK: Login and filter

        @Test func `the first account stream logs in, then filters to its channel and markets`() async throws {
            let streams = Streams.test(server, account: AccountStreamSupport.account)
            let orders = streams.orders(["BTC_USDT"])

            #expect(await server.nextSent() == AccountStreamSupport.login)
            await server.send(#"{"channel":"rs.login","data":"success","ts":1}"#)
            #expect(await server.nextSent() == AccountStreamSupport.filter(#"{"filter":"order","rules":["BTC_USDT"]}"#))
            withExtendedLifetime(orders) {}
        }

        @Test func `the filter names every stream's markets, and every market when a stream wants all`() async throws {
            let streams = Streams.test(server, account: AccountStreamSupport.account)
            let bitcoin = streams.orders(["BTC_USDT"])
            try await logIn()
            _ = await server.nextSent()

            let ether = streams.orders(["ETH_USDT"])
            #expect(await server.nextSent() == AccountStreamSupport.filter(#"{"filter":"order","rules":["BTC_USDT","ETH_USDT"]}"#))
            let positions = streams.positions()
            #expect(
                await server.nextSent()
                    == AccountStreamSupport.filter(
                        #"{"filter":"order","rules":["BTC_USDT","ETH_USDT"]},{"filter":"position"}"#
                    ))
            let balances = streams.balances()
            #expect(
                await server.nextSent()
                    == AccountStreamSupport.filter(
                        #"{"filter":"asset"},{"filter":"order","rules":["BTC_USDT","ETH_USDT"]},{"filter":"position"}"#
                    ))
            withExtendedLifetime((bitcoin, ether, positions, balances)) {}
        }

        @Test func `the filter shrinks when a stream ends, and the connection closes after the last`() async throws {
            let streams = Streams.test(server, account: AccountStreamSupport.account)
            var closes = server.closes.makeAsyncIterator()
            var bitcoin: AsyncThrowingStream<MexcFutures.Order, any Error>? = streams.orders(["BTC_USDT"])
            try await logIn()
            _ = await server.nextSent()
            var ether: AsyncThrowingStream<MexcFutures.Order, any Error>? = streams.orders(["ETH_USDT"])
            _ = await server.nextSent()

            bitcoin = nil
            #expect(await server.nextSent() == AccountStreamSupport.filter(#"{"filter":"order","rules":["ETH_USDT"]}"#))
            ether = nil
            await closes.next()
            // An empty filter would turn every private channel back on, so none is sent.
            #expect(await server.sentCount == 4)
            withExtendedLifetime((bitcoin, ether)) {}
        }

        @Test func `one stream wanting every market leaves the key's markets out, and fills filter on order.deal`() async throws {
            let streams = Streams.test(server, account: AccountStreamSupport.account)
            let bitcoin = streams.orders(["BTC_USDT"])
            let every = streams.orders()
            let fills = streams.fills(["ETH_USDT"])
            try await logIn()

            // The streams may join before or after the first filter, so the last of up to three counts.
            let expected = AccountStreamSupport.filter(#"{"filter":"order"},{"filter":"order.deal","rules":["ETH_USDT"]}"#)
            var filter = await server.nextSent()
            for _ in 0..<2 where filter != expected {
                filter = await server.nextSent()
            }
            #expect(filter == expected)
            withExtendedLifetime((bitcoin, every, fills)) {}
        }

        @Test func `a stream of a channel without a filter key turns every channel on until it ends`() async throws {
            let streams = Streams.test(server, account: AccountStreamSupport.account)
            let orders = streams.orders(["BTC_USDT"])
            try await logIn()
            #expect(await server.nextSent() == AccountStreamSupport.filter(#"{"filter":"order","rules":["BTC_USDT"]}"#))

            var trailing: AsyncThrowingStream<MexcFutures.TrailingOrder, any Error>? = streams.trailingOrders()
            #expect(await server.nextSent() == AccountStreamSupport.filter(""))
            trailing = nil
            #expect(await server.nextSent() == AccountStreamSupport.filter(#"{"filter":"order","rules":["BTC_USDT"]}"#))
            withExtendedLifetime((orders, trailing)) {}
        }

        @Test func `a stream that joins while the filter is empty survives a reconnect that first fails`() async throws {
            let streams = Streams.test(server, account: AccountStreamSupport.account)
            let trailing = streams.trailingOrders()
            try await logIn()
            #expect(await server.nextSent() == AccountStreamSupport.filter(""))
            let orders = Task { try await AccountStreamSupport.take(1, from: streams.orders()) }
            // Joining changes nothing MEXC is told, so nothing is sent; give the stream time to join.
            try await Task.sleep(for: .milliseconds(100))

            await server.failConnections(1)
            await server.drop()
            try await logIn()
            #expect(await server.nextSent() == AccountStreamSupport.filter(""))
            await server.send(.binary(try AccountStreamSupport.push("push.personal.order", .orderChange(Self.order))))
            #expect(try await orders.value.map(\.id.rawValue) == ["123456789"])
            withExtendedLifetime(trailing) {}
        }

        @Test func `streams only of channels without a filter key send an empty filter`() async throws {
            let streams = Streams.test(server, account: AccountStreamSupport.account)
            let modes = streams.positionModes()
            try await logIn()
            #expect(await server.nextSent() == AccountStreamSupport.filter(""))
            withExtendedLifetime(modes) {}
        }

        @Test func `an account stream started after the last one ended logs in again`() async throws {
            let streams = Streams.test(server, account: AccountStreamSupport.account)
            var closes = server.closes.makeAsyncIterator()
            var first: AsyncThrowingStream<MexcFutures.Order, any Error>? = streams.orders()
            try await logIn()
            _ = await server.nextSent()
            first = nil
            await closes.next()

            let second = streams.orders()
            try await logIn()
            #expect(await server.nextSent() == AccountStreamSupport.filter(#"{"filter":"order"}"#))
            withExtendedLifetime((first, second)) {}
        }

        @Test func `a login MEXC doesn't acknowledge fails the streams with acknowledgementTimedOut`() async throws {
            let streams = Streams.test(server, account: AccountStreamSupport.account)
            let orders = Task { try await AccountStreamSupport.take(1, from: streams.orders()) }
            #expect(await server.nextSent() == AccountStreamSupport.login)

            let error = try await #require(throws: MexcFutures.ClientError.self) { try await orders.value }
            #expect(error.reason == .acknowledgementTimedOut)
            #expect(error.message == "the login")
        }

        @Test func `a login rejected after a reconnect ends the running account streams`() async throws {
            let streams = Streams.test(server, account: AccountStreamSupport.account)
            let orders = Task { try await AccountStreamSupport.take(1, from: streams.orders()) }
            try await logIn()
            _ = await server.nextSent()

            await server.drop()
            #expect(await server.nextSent() == AccountStreamSupport.login)
            await server.send(#"{"channel":"rs.error","data":"Api key info invalid","ts":1}"#)
            let error = try await #require(throws: MexcFutures.ClientError.self) { try await orders.value }
            #expect(error.reason == .loginRejected)
        }

        @Test func `the account connection sends no unsubscribe, and market streams no login`() async throws {
            let streams = Streams.test(server, account: AccountStreamSupport.account)
            var positions: AsyncThrowingStream<MexcFutures.Position, any Error>? = streams.positions()
            let orders = streams.orders()
            try await logIn()
            _ = await server.nextSent()
            positions = nil
            #expect(await server.nextSent() == AccountStreamSupport.filter(#"{"filter":"order"}"#))

            let otherServer = FakeWebSocketServer()
            let ticker = Streams.test(otherServer, account: AccountStreamSupport.account).ticker("BTC_USDT")
            #expect(await otherServer.nextSent() == #"{"method":"sub.ticker","param":{"symbol":"BTC_USDT"}}"#)
            withExtendedLifetime((positions, orders, ticker)) {}
        }

        @Test func `a rejected login fails every account stream with loginRejected`() async throws {
            let streams = Streams.test(server, account: AccountStreamSupport.account)
            let orders = Task { try await AccountStreamSupport.take(1, from: streams.orders()) }
            _ = await server.nextSent()
            await server.send(#"{"channel":"rs.error","data":"Api key info invalid","ts":1}"#)

            let error = try await #require(throws: MexcFutures.ClientError.self) { try await orders.value }
            #expect(error.reason == .loginRejected)
            #expect(error.message == "Api key info invalid")
        }

        @Test func `account streams without credentials throw missingCredentials before connecting`() async throws {
            let streams = Streams.test(server, account: StreamConnection.Account(credentials: nil, clock: ServerClock()))
            let orders = Task { try await AccountStreamSupport.take(1, from: streams.orders()) }

            let error = try await #require(throws: MexcFutures.ClientError.self) { try await orders.value }
            #expect(error.reason == .missingCredentials)
            #expect(await server.connectAttempts == 0)
        }

        @Test func `after a drop the account connection logs in and filters again`() async throws {
            let streams = Streams.test(server, account: AccountStreamSupport.account)
            let orders = Task { try await AccountStreamSupport.take(1, from: streams.orders()) }
            try await logIn()
            let filter = await server.nextSent()

            await server.drop()
            #expect(await server.nextSent() == AccountStreamSupport.login)
            await server.send(#"{"channel":"rs.login","data":"success","ts":1}"#)
            #expect(await server.nextSent() == filter)
            await server.send(.binary(try AccountStreamSupport.push("push.personal.order", .orderChange(Self.order))))
            #expect(try await orders.value.map(\.id.rawValue) == ["123456789"])
        }

        // MARK: Markets

        @Test func `a push of a market a stream doesn't want can't end it, even when it doesn't decode`() async throws {
            let streams = Streams.test(server, account: AccountStreamSupport.account)
            let bitcoin = Task { try await AccountStreamSupport.take(1, from: streams.orders(["BTC_USDT"])) }
            try await logIn()
            _ = await server.nextSent()

            var broken = Self.order
            broken.symbol = "ETH_USDT"
            broken.clearCreateTime()
            await server.send(.binary(try AccountStreamSupport.push("push.personal.order", .orderChange(broken))))
            await server.send(.binary(try AccountStreamSupport.push("push.personal.order", .orderChange(Self.order))))
            #expect(try await bitcoin.value.map(\.symbol) == ["BTC_USDT"])
        }

        @Test func `each stream gets only its own markets' pushes`() async throws {
            let streams = Streams.test(server, account: AccountStreamSupport.account)
            let bitcoin = Task { try await AccountStreamSupport.take(1, from: streams.orders(["BTC_USDT"])) }
            try await logIn()
            _ = await server.nextSent()
            let ether = Task { try await AccountStreamSupport.take(1, from: streams.orders(["ETH_USDT"])) }
            _ = await server.nextSent()

            var etherOrder = Self.order
            etherOrder.symbol = "ETH_USDT"
            await server.send(.binary(try AccountStreamSupport.push("push.personal.order", .orderChange(etherOrder))))
            await server.send(.binary(try AccountStreamSupport.push("push.personal.order", .orderChange(Self.order))))

            #expect(try await ether.value.map(\.symbol) == ["ETH_USDT"])
            #expect(try await bitcoin.value.map(\.symbol) == ["BTC_USDT"])
        }

        // MARK: Pushes

        @Test func `an order push decodes into an order without attached stops`() async throws {
            let order = try await first(
                of: Streams.test(server, account: AccountStreamSupport.account).orders(), push: .orderChange(Self.order),
                on: "push.personal.order")
            #expect(order.id.rawValue == "123456789")
            #expect(order.symbol == "BTC_USDT")
            #expect(order.position?.rawValue == "987654321")
            #expect(order.side == .openLong)
            #expect(order.type == .limit)
            #expect(order.category == .limit)
            #expect(order.state == .open)
            #expect(order.marginMode == .isolated)
            #expect(order.leverage == 20)
            #expect(order.price == Decimal(string: "45000.5"))
            #expect(order.volume == 10)
            #expect(order.filledVolume == 5)
            #expect(order.averageFillPrice == 45000)
            #expect(order.margin == 2250)
            #expect(order.usedMargin == 1125)
            #expect(order.takerFee == Decimal(string: "0.1125"))
            #expect(order.makerFee == Decimal(string: "0.09"))
            #expect(order.feeAsset == "USDT")
            #expect(order.profit == 0)
            #expect(order.takeProfit == nil && order.stopLoss == nil && order.totalFee == nil)
            #expect(order.bestPrice == nil)
            #expect(order.externalID == "ext_001")
            #expect(order.errorCode == MexcFutures.OrderErrorCode(rawValue: 0))
            #expect(order.positionMode == .hedge)
            #expect(order.reduceOnly == false)
            #expect(order.createdAt == Date(timeIntervalSince1970: 1_760_942_212))
            #expect(order.updatedAt == Date(timeIntervalSince1970: 1_760_942_212))
        }

        @Test func `a fill push decodes into a fill`() async throws {
            let fill = try await first(
                of: Streams.test(server, account: AccountStreamSupport.account).fills(), push: .orderDealDetail(Self.fill),
                on: "push.personal.order.deal")
            #expect(fill.id.rawValue == "987654321")
            #expect(fill.symbol == "BTC_USDT")
            #expect(fill.order?.rawValue == "123456789")
            #expect(fill.side == .openLong)
            #expect(fill.price == Decimal(string: "45000.5"))
            #expect(fill.volume == 10)
            #expect(fill.fee == Decimal(string: "0.225"))
            #expect(fill.feeAsset == "USDT")
            #expect(fill.profit == 0)
            #expect(fill.category == .limit)
            #expect(fill.isTaker == true)
            #expect(fill.positionMode == .hedge)
            #expect(fill.filledAt == Date(timeIntervalSince1970: 1_760_942_212))
        }

        @Test func `a position push decodes into a position`() async throws {
            let position = try await first(
                of: Streams.test(server, account: AccountStreamSupport.account).positions(), push: .positionChange(Self.position),
                on: "push.personal.position")
            #expect(position.id.rawValue == "123456789")
            #expect(position.symbol == "BTC_USDT")
            #expect(position.side == .long)
            #expect(position.marginMode == .isolated)
            #expect(position.state == .holding)
            #expect(position.leverage == 20)
            #expect(position.volume == 10)
            #expect(position.frozenVolume == 0)
            #expect(position.closedVolume == 0)
            #expect(position.averageClosePrice == 0)
            #expect(position.funding == 0)
            #expect(position.realizedProfit == 0)
            #expect(position.closingProfit == 0)
            #expect(position.fee == 0)
            #expect(position.updatedAt == Date(timeIntervalSince1970: 1_760_942_212))
            #expect(position.averagePrice == Decimal(string: "45000.5"))
            #expect(position.averageOpenPrice == Decimal(string: "45000.5"))
            #expect(position.liquidationPrice == 40000)
            #expect(position.initialMargin == Decimal(string: "2250.025"))
            #expect(position.originalInitialMargin == Decimal(string: "2250.025"))
            #expect(position.unrealizedProfit == Decimal(string: "100.5"))
            #expect(position.marginRatio == Decimal(string: "0.2"))
            #expect(position.addsMarginAutomatically == false)
            #expect(position.autoDeleveragingLevel == 1)
            #expect(position.profitRatio == nil && position.totalFee == nil)
            #expect(position.createdAt == Date(timeIntervalSince1970: 1_760_942_212))
        }

        @Test func `a balance push decodes its asset and amounts`() async throws {
            let balance = try await first(
                of: Streams.test(server, account: AccountStreamSupport.account).balances(), push: .assetChange(Self.balance),
                on: "push.personal.asset")
            #expect(
                balance
                    == MexcFutures.BalanceUpdate(
                        asset: "USDT", available: 9000, frozen: 1000, positionMargin: 5000, trialBonus: 100
                    ))
        }

        @Test func `an order's zero position and fill price are none, and its best price is kept`() async throws {
            var order = Self.order
            order.positionID = 0
            order.dealAvgPrice = "0"
            order.bboTypeNum = 2
            let decoded = try await first(
                of: Streams.test(server, account: AccountStreamSupport.account).orders(), push: .orderChange(order),
                on: "push.personal.order"
            )
            #expect(decoded.position == nil)
            #expect(decoded.averageFillPrice == nil)
            #expect(decoded.bestPrice == MexcFutures.BestPrice(rawValue: 2))
        }

        @Test func `a position push without the automatic margin flag reads it as off`() async throws {
            var position = Self.position
            position.clearAutoAddIm()
            let decoded = try await first(
                of: Streams.test(server, account: AccountStreamSupport.account).positions(), push: .positionChange(position),
                on: "push.personal.position"
            )
            #expect(!decoded.addsMarginAutomatically)
        }

        @Test(arguments: ["createTime", "side"])
        func `an order push without a required value ends the stream with DecodingError`(missing: String) async throws {
            var order = Self.order
            if missing == "createTime" { order.clearCreateTime() } else { order.side = 0 }
            let streams = Streams.test(server, account: AccountStreamSupport.account)
            let orders = Task { try await AccountStreamSupport.take(1, from: streams.orders()) }
            try await logIn()
            _ = await server.nextSent()
            await server.send(.binary(try AccountStreamSupport.push("push.personal.order", .orderChange(order))))

            await #expect(throws: DecodingError.self) { try await orders.value }
        }

        // MARK: Helpers

        /// Answers the login.
        private func logIn() async throws {
            #expect(await server.nextSent() == AccountStreamSupport.login)
            await server.send(#"{"channel":"rs.login","data":"success","ts":1}"#)
        }

        /// Logs in, sends `push` and returns the stream's first value.
        private func first<Element: Sendable>(
            of stream: AsyncThrowingStream<Element, any Error>, push data: ContractWrapper.OneOf_Data, on channel: String
        ) async throws -> Element {
            try await logIn()
            _ = await server.nextSent()
            await server.send(.binary(try AccountStreamSupport.push(channel, data)))
            var values = stream.makeAsyncIterator()
            let value = try await values.next()
            return try #require(value)
        }

        // The examples on MEXC's documentation pages, as Protobuf messages.

        private static let order = OrderChange.with {
            $0.orderID = "123456789"
            $0.symbol = "BTC_USDT"
            $0.positionID = 987_654_321
            $0.price = "45000.5"
            $0.vol = "10"
            $0.leverage = 20
            $0.side = 1
            $0.category = 1
            $0.orderType = 1
            $0.dealAvgPrice = "45000.0"
            $0.dealVol = "5"
            $0.orderMargin = "2250.0"
            $0.usedMargin = "1125.0"
            $0.takerFee = "0.1125"
            $0.makerFee = "0.09"
            $0.profit = "0"
            $0.feeCurrency = "USDT"
            $0.openType = 1
            $0.state = 2
            $0.errorCode = 0
            $0.externalOid = "ext_001"
            $0.createTime = 1_760_942_212_000
            $0.updateTime = 1_760_942_212_000
            $0.remainVol = "5"
            $0.positionMode = 1
            $0.reduceOnly = false
            $0.bboTypeNum = 0
            $0.makerFeeRate = "0.0002"
            $0.takerFeeRate = "0.0004"
        }

        private static let fill = OrderDealDetail.with {
            $0.id = "987654321"
            $0.symbol = "BTC_USDT"
            $0.side = 1
            $0.vol = "10"
            $0.price = "45000.5"
            $0.feeCurrency = "USDT"
            $0.fee = "0.225"
            $0.timestamp = 1_760_942_212_000
            $0.profit = "0"
            $0.taker = true
            $0.category = 1
            $0.orderID = "123456789"
            $0.isSelf = false
            $0.externalOid = "ext_001"
            $0.positionMode = 1
            $0.reduceOnly = false
            $0.opponentUid = 987_654_321
        }

        private static let position = PositionChange.with {
            $0.positionID = 123_456_789
            $0.symbol = "BTC_USDT"
            $0.holdVol = "10"
            $0.positionType = 1
            $0.openType = 1
            $0.state = 1
            $0.frozenVol = "0"
            $0.closeVol = "0"
            $0.holdAvgPrice = "45000.5"
            $0.holdAvgPriceFullyScale = "45000.500000000000000000"
            $0.closeAvgPrice = "0"
            $0.openAvgPrice = "45000.5"
            $0.openAvgPriceFullyScale = "45000.500000000000000000"
            $0.liquidatePrice = "40000.0"
            $0.oim = "2250.025"
            $0.adlLevel = 1
            $0.im = "2250.025"
            $0.holdFee = "0"
            $0.realised = "0"
            $0.leverage = 20
            $0.autoAddIm = false
            $0.pnl = "100.5"
            $0.marginRatio = "0.2"
            $0.closeProfitLoss = "0"
            $0.fee = "0"
            $0.makerFeeRate = "0.0002"
            $0.takerFeeRate = "0.0004"
            $0.createTime = 1_760_942_212_000
            $0.updateTime = 1_760_942_212_000
            $0.version = 1
        }

        private static let balance = AssetChange.with {
            $0.currency = "USDT"
            $0.positionMargin = "5000.0"
            $0.frozenBalance = "1000.0"
            $0.availableBalance = "9000.0"
            $0.bonus = "100.0"
        }
    }
}
