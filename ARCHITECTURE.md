# Architecture

MexcKit is a Swift SDK for MEXC futures: the Market, Account and Trade REST endpoints and the WebSocket streams. This file is for contributors.

## Targets

```text
Your app
└── MexcKit        product; the live client over REST and WebSocket; re-exports MexcKitCore
    └── MexcKitCore  product; the contract: namespace, models, vocabularies, protocols, errors, credentials
```

- Dependencies point one way: app, `MexcKit`, `MexcKitCore`, platform.
- `MexcKitCore` depends only on Foundation. It is a product so a module that needs only the contract (protocols and models, for mocking or dependency injection) doesn't compile NIO or BoringSSL.
- `MexcKit` depends on AsyncHTTPClient (REST), SwiftNIO (the byte, header and time types AsyncHTTPClient's API takes), WebSocketKit (streams) and swift-crypto (HMAC request signing; it wraps CryptoKit on Apple platforms). None of their types appears in a public signature: `import MexcKit` is all an app writes. Only the transport conformers import AsyncHTTPClient, SwiftNIO and WebSocketKit.
- Every API type is nested in `MexcFutures`, so names like `Order` or `Position` can't collide with an app's types or another exchange SDK. Only `MexcError` and `MexcCredentials` sit at the top level, where a future spot module can share them.

## Settings

Every target builds in the Swift 6 language mode with `ApproachableConcurrency`, `ExistentialAny`, `InternalImportsByDefault` and `MemberImportVisibility`. Code is nonisolated by default: no target sets a default actor isolation, so an app on any actor can call the SDK. Mark CPU-heavy work, such as decoding large responses, `@concurrent` so it leaves the caller's actor.

Import `Foundation` with a plain `import Foundation`, not `FoundationEssentials`. Write `public import Foundation` only in a file whose public signatures use a Foundation type, and `package import Foundation` only in one whose `package` signatures do.

## Errors

- `MexcError`: a failure MEXC reported, from its response envelope or an HTTP error status.
- `MexcFutures.ClientError`: a failure the client detected, including network failures (`.timedOut`, `.connectionFailed`). AsyncHTTPClient's, SwiftNIO's and Network.framework's errors never reach apps directly: the transport wraps them, keeping the original in `underlyingError` for diagnostics. This departs from passing platform errors through, because these are vendor types that differ by platform and would make apps import AsyncHTTPClient to catch them.
- `DecodingError` and `CancellationError` pass through unchanged.

## Access

| Level | For |
|---|---|
| `public` | What apps use |
| `package` | What another target writes today |
| nothing written | The rest of a target. Never write `internal` |
| `private` | What one file uses, such as wire types and coding keys |

## Folders and files

- In `MexcKitCore` and `MexcKit`, a file with no `public` declaration goes in `Internal/`, so a module's root shows what apps can use.
- A file owns one responsibility and is named after its primary type. Wire types live, `private`, in the file that reads or writes them.
- Tests mirror the sources: `MexcKitCoreTests` for the contract, `MexcKitTests` for the client. `MexcKitTestSupport` (in `Tests/`, not a product) holds the live test gate (`areLiveTestsEnabled`, `LiveTestSettings`) and the `.live` tag. In `MexcKitTests`, `Loopback/` sends real requests to a local server, `Live/` calls MEXC's servers, `Support/` holds fakes and helpers, and `Fixtures/` holds responses recorded from MEXC, byte for byte except for replaced IDs. Private endpoints' fixtures are the examples in MEXC's documentation until a response is recorded with a key; their test suites say so.

Files of one kind use the same `// MARK: -` sections in the same order; a section that doesn't apply is left out:

| Kind | Sections |
|---|---|
| A domain protocol | Protocol · Defaults · Requests |
| A model | Model · Reading · Wire |
| A domain conformer | Endpoints · Wire |
| The stream connection | Connection · Subscribing · Receiving · Recovering · Wire |

## Vocabulary

One word per concept in code, comments and docs.

| Word | Means | MEXC names |
|---|---|---|
| deal | one public trade | `deals`, `push.deal` |
| fill | one execution of the caller's order | `order_deals`, `deal_details`, `push.personal.order.deal` |
| pending order | an order not yet final | "open orders", "current orders", "in-flight" |
| plan order | a trigger order that places an order | `planorder/*`, `plan.order` |
| stop order | a take-profit or stop-loss order on a position | `stoporder/*`, `stopPlanOrderId`, `stop.planorder` |
| attached stop | take-profit and stop-loss prices carried by a limit order | `stoporder/change_price`, `stop.order` |
| trailing order | a callback (trailing) order | `trackorder/*`, `track.order` |
| volume | size in contracts | `vol` |
| contract | a futures market: its symbol and trading rules | "contract", "contract detail" |
| balance | the futures account's holdings of one asset | "assets", "asset" |
| funding payment | the funding one position paid or received at a settlement | "funding records", `holdFee` |
