import Foundation
import MexcKit

/// The code of the documentation's examples, in the DocC articles and the README, so a change that
/// breaks one fails the build. `DocumentationExampleTests` checks that each example's lines appear,
/// in order, in one of these functions; a function may add lines that use its values.
///
/// Nothing runs them: they call MEXC, and one places an order.
enum DocumentationExamples {
    // MARK: Landing page and README

    static func landingPage() async throws {
        let client = MexcFutures.Client()
        let ticker = try await client.market.ticker("BTC_USDT")
        _ = ticker
    }

    static func quickStart(apiKey: String, secret: String) async throws {
        let client = MexcFutures.Client(credentials: MexcCredentials(apiKey: apiKey, secret: secret))

        let ticker = try await client.market.ticker("BTC_USDT")
        print(ticker.lastPrice, ticker.bestBid ?? 0, ticker.bestAsk ?? 0)

        for try await ticker in client.stream.ticker("BTC_USDT") {
            print(ticker.lastPrice)
        }
    }

    // MARK: Getting started

    static func createClients(apiKey: String, secret: String) {
        let client = MexcFutures.Client(credentials: MexcCredentials(apiKey: apiKey, secret: secret))

        // Market data and market streams need no credentials.
        let publicClient = MexcFutures.Client()

        _ = (client, publicClient)
    }

    static func readTicker(client: MexcFutures.Client) async throws {
        let ticker = try await client.market.ticker("BTC_USDT")
        print(ticker.lastPrice, ticker.bestBid ?? 0, ticker.bestAsk ?? 0)
    }

    static func placeAndCancelOrder(client: MexcFutures.Client) async throws {
        let contract = try await client.market.contract("BTC_USDT")
        let lastPrice = try await client.market.ticker("BTC_USDT").lastPrice
        let options = MexcFutures.OrderRequest.Options(positionMode: try await client.account.positionMode())

        // A buy 5% below the market rests in the book.
        let price = contract.round(price: lastPrice * 95 / 100, rule: .down)
        let request = MexcFutures.OrderRequest.open(
            .long, "BTC_USDT", .limit(price: price),
            volume: contract.minimumVolume, leverage: 5, marginMode: .isolated, options: options
        )
        let placed = try await client.order.place(request)
        try await client.order.cancel(placed.id)
    }

    static func streamMarket(client: MexcFutures.Client) async throws {
        for try await ticker in client.stream.ticker("BTC_USDT") {
            print(ticker.lastPrice)
        }
    }

    static func streamAccount(client: MexcFutures.Client) async throws {
        for try await order in client.stream.orders(["BTC_USDT"]) {
            print(order.id, order.state)
        }
    }

    static func keepOrderBook(client: MexcFutures.Client) async throws {
        for try await book in MexcFutures.OrderBookSync("BTC_USDT", client: client) {
            print(book.bids.first?.price ?? 0, book.asks.first?.price ?? 0)
        }
    }

    static func handleErrors(client: MexcFutures.Client, request: MexcFutures.OrderRequest) async {
        do {
            _ = try await client.order.place(request)
        } catch let error as MexcError where error.code == .insufficientBalance {
            print("Not enough margin:", error.localizedDescription)
        } catch let error as MexcError {
            print("MEXC refused the order:", error.code, error.localizedDescription)
        } catch let error as MexcFutures.ClientError where error.reason == .timedOut {
            // The order may still have reached MEXC: read the orders before placing it again.
            print("No answer in time:", error.localizedDescription)
        } catch let error as MexcFutures.ClientError {
            print("The client couldn't place the order:", error.reason, error.localizedDescription)
        } catch {
            print(error.localizedDescription)
        }
    }
}
