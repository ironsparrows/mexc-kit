# MexcKit

A Swift SDK for MEXC futures: market data, the account, orders, plan, stop and trailing orders,
position settings, and live market and account streams over Protobuf WebSockets.

MexcKit is not affiliated with MEXC. Its calls trade real money on a real account: test with small
amounts.

- Swift 6.4, strict concurrency, `async`/`await` throughout.
- Prices and volumes are `Decimal`, read exactly as MEXC sends them.
- One protocol per domain, so tests can mock what they use.
- Errors say who failed: `MexcError` when MEXC refuses a call, with MEXC's code and message;
  `MexcFutures.ClientError` when the client couldn't complete it.

## Requirements

Swift 6.4 or later (Xcode 27.2 or later on Apple platforms). macOS 13, iOS 16, tvOS 16 and
visionOS 1. Linux is a target platform, not yet built or tested. watchOS is not supported.

## Installation

Add the package with Swift Package Manager, then add the `MexcKit` product to your target:

```swift
.package(url: "https://github.com/dioKaratzas/mexc-kit.git", from: "0.1.0"),
```

```swift
.product(name: "MexcKit", package: "mexc-kit"),
```

In an Xcode project, use File > Add Package Dependencies and enter the repository URL.

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

## Documentation

The DocC catalog covers every type and a getting-started guide: creating a client, placing and
canceling an order, streaming, keeping a local order book and handling errors. Build it in Xcode with
Product > Build Documentation, or:

```bash
xcodebuild docbuild -scheme MexcKit -destination 'generic/platform=macOS'
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the checks, the live tests and the commit style, and
[ARCHITECTURE.md](ARCHITECTURE.md) for the layout and vocabulary.

## License

Apache License 2.0; see [LICENSE](LICENSE). MEXC's `.proto` files in `Sources/MexcKitProtobuf/Proto`
are also Apache 2.0, under their own [LICENSE](Sources/MexcKitProtobuf/Proto/LICENSE).
