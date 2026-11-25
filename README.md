<div align="center">

# MexcKit

**A Swift SDK for MEXC futures.**

Market data, the account, orders and live streams, from one typed `async`/`await` client.

[![CI](https://github.com/ironsparrows/mexc-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/ironsparrows/mexc-kit/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/ironsparrows/mexc-kit)](https://github.com/ironsparrows/mexc-kit/releases/latest)
[![Swift 6.4](https://img.shields.io/badge/Swift-6.4-F05138?logo=swift&logoColor=white)](https://www.swift.org)
[![Platforms](https://img.shields.io/badge/platforms-macOS%2013%20%C2%B7%20iOS%2016%20%C2%B7%20tvOS%2016%20%C2%B7%20visionOS%201%20%C2%B7%20Linux-blue)](#installation)
[![License](https://img.shields.io/badge/license-Apache_2.0-blue.svg)](LICENSE)

[Quick start](#quick-start) ·
[Installation](#installation) ·
[Usage](#usage) ·
[Streams](#streams) ·
[Testing](#testing) ·
[Docs](#documentation)

</div>

> [!TIP]
> **Futures only.** MexcKit covers MEXC's futures REST API and its Protobuf WebSocket streams: market data, the
> account and fees, positions, orders, plan, stop and trailing orders, and self-trade prevention. Spot trading isn't
> included.

MexcKit is not affiliated with MEXC. Its calls trade real money on a real account: test with small amounts.

- **One client, one protocol per domain.** `client.market`, `client.account`, `client.position`, `client.order`,
  `client.stream` and more, each a protocol a test can replace with a mock.
- **Exact numbers.** Prices, volumes and rates are `Decimal`, read exactly as MEXC sends them.
- **Typed requests.** Order sides, types, margin modes and states are typed values, and IDs are their own types.
- **Live streams.** Public market streams and the account's orders, fills, positions and balances over Protobuf
  WebSockets, reconnecting and resubscribing after a drop.
- **A local order book.** `OrderBookSync` keeps a whole order book from a snapshot and its changes, catching up after
  a gap.
- **Errors that say who failed.** `MexcError` when MEXC refuses a call, with MEXC's code and message,
  and `MexcFutures.ClientError` when the client couldn't complete it.
- **Swift 6.4 throughout.** Strict concurrency, `Sendable` types and `async`/`await`.

## Quick start

With an API key and secret created on MEXC:

```swift
let client = MexcFutures.Client(credentials: MexcCredentials(apiKey: apiKey, secret: secret))

let ticker = try await client.market.ticker("BTC_USDT")
print(ticker.lastPrice, ticker.bestBid ?? 0, ticker.bestAsk ?? 0)

for try await ticker in client.stream.ticker("BTC_USDT") {
    print(ticker.lastPrice)
}
```

Market data and market streams need no credentials: `MexcFutures.Client()`.

## Installation

- Swift 6.4 or later, with Xcode 27.2 or later on Apple platforms.
- macOS 13, iOS 16, tvOS 16 or visionOS 1. watchOS isn't supported.
- Linux, which CI builds and tests in the official `swift:6.4` image.

Add the package with Swift Package Manager, then add the `MexcKit` product to your target:

```swift
.package(url: "https://github.com/ironsparrows/mexc-kit.git", from: "0.1.0"),
```

```swift
.product(name: "MexcKit", package: "mexc-kit"),
```

In an Xcode project, use File > Add Package Dependencies and enter the repository URL.

## Usage

One `MexcFutures.Client` holds every capability, grouped by domain. Read the contract for its trading rules, round the
price to its tick, and size the order in contracts:

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

MEXC treats an order as placed in hedge mode unless its options say otherwise, so pass the account's position mode.
Plan, stop and trailing orders have their own domains: `client.planOrder`, `client.stopOrder` and
`client.trailingOrder`.

A call throws `MexcError` when MEXC refuses it and `MexcFutures.ClientError` when the client couldn't complete it:

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

## Streams

Streams are `AsyncThrowingStream`s. A stream subscribes when it's made and unsubscribes when the loop over it ends:

```swift
for try await ticker in client.stream.ticker("BTC_USDT") {
    print(ticker.lastPrice)
}
```

The account's orders, fills, positions and balances stream the same way, on a second connection that logs in with the
client's credentials:

```swift
for try await order in client.stream.orders(["BTC_USDT"]) {
    print(order.id, order.state)
}
```

The client reconnects after a drop on its own, but pushes sent while it was disconnected are lost. To keep a whole
order book, use `MexcFutures.OrderBookSync`, which catches up after a gap:

```swift
for try await book in MexcFutures.OrderBookSync("BTC_USDT", client: client) {
    print(book.bids.first?.price ?? 0, book.asks.first?.price ?? 0)
}
```

## Testing

`swift test` runs offline. The live suites call MEXC's servers and run only when `MEXC_API_KEY` and `MEXC_API_SECRET`
are set; otherwise they skip, and CI never sets them.

> [!WARNING]
> With keys set, five live suites change the account, and four of them place small real orders and open real
> positions, with real fees. [CONTRIBUTING.md](CONTRIBUTING.md#running-live-tests) lists what each suite does, what
> the account needs and how to set the keys without echoing them.

```bash
swift test --filter Live
```

## Documentation

The [documentation](https://ironsparrows.github.io/mexc-kit/documentation/mexckit/) is published to GitHub Pages
with each release. It covers every type, with a getting-started guide: creating a client, placing and canceling an
order, streaming, keeping a local order book and handling errors. Build it locally in Xcode with
Product > Build Documentation, or:

```bash
xcodebuild docbuild -scheme MexcKit -destination 'generic/platform=macOS'
```

## Contributing

Report bugs and ask questions in [Issues](https://github.com/ironsparrows/mexc-kit/issues). Pull requests are
welcome. For a larger change, such as a new domain or spot trading, open an issue first. [CONTRIBUTING.md](CONTRIBUTING.md) says how to format, build and
test, how to run the live suites, and how releases are made. [ARCHITECTURE.md](ARCHITECTURE.md) describes the
layout and the vocabulary.

## Related projects

- [HyperliquidKit](https://github.com/ironsparrows/hyperliquid-kit): the same kind of Swift SDK for Hyperliquid's perpetuals.
- [Swift Language Models](https://github.com/ironsparrows/swift-language-models): Apple's Foundation Models API for
  every provider's language models.

## License

Licensed under the Apache License 2.0. See [LICENSE](LICENSE). MEXC's `.proto` files in
`Sources/MexcKitProtobuf/Proto` are also Apache 2.0, under their own
[LICENSE](Sources/MexcKitProtobuf/Proto/LICENSE).
