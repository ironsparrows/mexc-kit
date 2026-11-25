# Getting started

Create a client, read market data, place and cancel an order, stream a market and handle errors.

## Overview

Add `MexcKit` to your target, and import it with Foundation, which the examples use for `Decimal`.

### Create a client

A client with credentials can call every endpoint its API key's permissions allow. Create the key
on MEXC with the permissions your app needs, such as View Account Details, View Order Details and
Order Placing. Self-trade prevention groups also need a market maker account.

```swift
let client = MexcFutures.Client(credentials: MexcCredentials(apiKey: apiKey, secret: secret))

// Market data and market streams need no credentials.
let publicClient = MexcFutures.Client()
```

A client without credentials throws ``MexcFutures/ClientError/Reason/missingCredentials`` from
private calls, before sending anything. To read the credentials from storage before each private
request instead, so a rotated key takes effect at once, create the ``MexcFutures/Client``
with a closure that returns ``MexcCredentials``.

Keep one client for the app: it holds the stream connections and the offset to MEXC's clock.
Call ``MexcFutures/Client/synchronizeClock()`` once when the device's clock may be wrong, because
MEXC rejects private requests signed with a time more than 10 seconds off its own.

### Read a ticker

```swift
let ticker = try await client.market.ticker("BTC_USDT")
print(ticker.lastPrice, ticker.bestBid ?? 0, ticker.bestAsk ?? 0)
```

Symbols are string literals of ``MexcFutures/Symbol``. Prices and volumes are `Decimal`; build your
own from strings or integers, such as `Decimal(string: "0.95")!`, because a floating-point literal
isn't exact as a `Decimal`.

### Place and cancel an order

Read the contract for its trading rules, round the price to its tick, and size the order in
contracts:

```swift
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
```

MEXC treats an order as placed in hedge mode unless its options say otherwise, so pass the
account's position mode. MEXC rejects a limit price too far from the market price; 5% stays
inside that limit. ``MexcFutures/OrderRequest`` builds every kind of order with
``MexcFutures/OrderRequest/open(_:_:_:volume:leverage:marginMode:takeProfit:stopLoss:externalID:options:)``
and ``MexcFutures/OrderRequest/close(_:_:_:volume:marginMode:position:externalID:options:)``. Plan, stop
and trailing orders have their own domains: `client.planOrder`, `client.stopOrder` and
`client.trailingOrder`.

### Stream a market

Streams are `AsyncThrowingStream`s. A stream subscribes when it's made and unsubscribes when the
loop over it ends:

```swift
for try await ticker in client.stream.ticker("BTC_USDT") {
    print(ticker.lastPrice)
}
```

The account's orders, fills, positions and balances stream the same way, on a second connection
that logs in with the client's credentials:

```swift
for try await order in client.stream.orders(["BTC_USDT"]) {
    print(order.id, order.state)
}
```

The client reconnects after a drop on its own, but pushes sent while it was disconnected are lost.
To keep a whole order book, use ``MexcFutures/OrderBookSync``, which catches up after a gap:

```swift
for try await book in MexcFutures.OrderBookSync("BTC_USDT", client: client) {
    print(book.bids.first?.price ?? 0, book.asks.first?.price ?? 0)
}
```

### Handle errors

A call throws ``MexcError`` when MEXC refuses it, with MEXC's ``MexcError/code`` and message, and
``MexcFutures/ClientError`` when the client couldn't complete it, such as when MEXC doesn't answer
in time. Given an order `request`:

```swift
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
```

A request that times out, loses its connection (``MexcFutures/ClientError/Reason/connectionFailed``)
or is cancelled may still have reached MEXC once it was sent. Cancelling the task that waits for a
call throws `CancellationError`, a response MEXC changed beyond what the client reads throws
`DecodingError`, and an error your credentials closure throws arrives unchanged.
