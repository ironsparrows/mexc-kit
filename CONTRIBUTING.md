# Contributing

Read [ARCHITECTURE.md](ARCHITECTURE.md) first: it lists the targets, the access rules and the words the code uses.

## Requirements

Swift 6.4 or later. On macOS, Xcode 27.2 or later for the iOS build.

Supported platforms: macOS 13, iOS 16, tvOS 16 and visionOS 1. Linux, which CI builds and tests in the official `swift:6.4` image. watchOS is not supported.

## Checks before a change lands

Run them in a clean copy of the repository, so a local settings file and its keys never take part:

```bash
copy=$(mktemp -d) && git ls-files -z --cached --others --exclude-standard | rsync -a --from0 --files-from=- ./ "$copy"/ && cd "$copy"
```

Git ignores the local settings file, so the copy never has it. Each run makes a new copy, so files you deleted or renamed don't linger. Stage a deleted tracked file (`git rm`) first: the copy stops at a listed file that is missing.

Then, from the copy:

```bash
swift format lint --strict -r Sources/MexcKit Sources/MexcKitCore Tests Package.swift
```

```bash
swift build --build-tests -Xswiftc -warnings-as-errors
```

```bash
swift test
```

```bash
xcodebuild build -scheme MexcKit -destination 'generic/platform=iOS'
```

```bash
xcodebuild docbuild -scheme MexcKit -destination 'generic/platform=macOS'
```

The documentation build must show no warnings from `MexcKit`, `MexcKitCore` or `MexcKitProtobuf`; the dependencies' own warnings are theirs. `MexcKit`'s archive is the documentation apps read: it includes every `MexcKitCore` type, which `MexcKitCore`'s own archive repeats for modules that import it alone.

The code of the documentation's examples and the README's lives in `Tests/MexcKitTests/PublicAPI/DocumentationExamples.swift`: `swift build --build-tests` compiles it, and `swift test` checks that each example's lines appear, in order, in one of its functions. Change both together.

`-Xswiftc -warnings-as-errors` applies to this package's targets only: SwiftPM compiles dependencies with their warnings suppressed.

Linux has no local check: CI builds and tests it in the official `swift:6.4` image, including the `MexcKitTestSupport` target, which imports Testing.

### Format

swift-format reads `.swift-format`, which is [swift-language-models](https://github.com/ironsparrows/swift-language-models)' configuration with one difference: `AllPublicDeclarationsHaveDocumentation` is off, so a public member whose name carries its meaning, such as `OrderType.limit`, needs no doc comment. Format before committing, from the repository:

```bash
swift format format -i -r Sources/MexcKit Sources/MexcKitCore Tests Package.swift
```

`Sources/MexcKitProtobuf` holds only MEXC's `.proto` files and the code generated from them, which stay as they come. Where a force unwrap or `try!` can't fail, mark it with `// swift-format-ignore: NeverForceUnwrap` or `NeverUseForceTry` and say why on the next line.

### CI

Pull requests and pushes to `main` run `.github/workflows/ci.yml`: on macOS, the format check, the build with warnings as errors and the tests; on Linux, the build and the tests. Live suites skip there: no workflow has MEXC's keys. The iOS, tvOS and visionOS builds and the documentation build run only before a release.

## Tests

- Swift Testing only, one `@Suite` per file, named after the suite and nested in its target's root suite: `extension MexcKitTests { @Suite("…") struct … }`. A live suite that places orders or changes settings nests in `extension MexcKitTests.LiveTrading` instead, which runs those suites one at a time. Put the file in the folder that mirrors what it tests.
- Unit tests run offline. A live test calls MEXC's servers: give its suite `.tags(.live)`, `.enabled(if: areLiveTestsEnabled, "Set MEXC_API_KEY and MEXC_API_SECRET to run")` and `.timeLimit(.minutes(2))`, and build its client with `MexcFutures.Client(credentials: LiveTestSettings.credentials)`. Both come from `MexcKitTestSupport`.
- Never put an API key or secret in a committed file, a fixture or a log.

### Running live tests

Live tests run when an API key and its secret are set; otherwise they skip. There is no other switch: with keys set, every live suite runs, including those that place real orders, in a plain `swift test` and in Xcode's Test action too. `swift test --skip Live` leaves them out.

**Five suites change the account, and four of them place small real orders and open real positions** on it, with real fees, in BTC_USDC at the contract's minimum volume and 5× isolated leverage. Its futures wallet needs USDC, which BTC_USDC settles in: about 15 is enough, and without it they fail at the first order with MEXC code 2005, "Balance insufficient". They run one at a time and undo what they change, but some act on the whole account: they close every position in every market (`position.closeAll()`), cancel every pending order in every market (`order.cancelAll()`), close the first BTC_USDC long they find, switch the account's position mode and back (MEXC refuses while any order or position is open, and leaving hedge mode resets the risk limit level to 1), and turn multi-asset mode on and then off, which leaves it off. Use an account with no orders or positions of its own. A failure partway can leave an order or a position open, a setting changed (leverage, automatic margin, position mode, multi-asset mode) or added margin on the test's position: check the account after a failed run.

| Suite | What it does |
|---|---|
| Live REST | Reads public market data and synchronizes the clock. |
| Live streams | Opens the public streams and checks their pushes decode. |
| Live order book sync | Keeps BTC_USDT's order book for a few changes. |
| Live account and positions | Reads the account, fees and positions. |
| Live position settings and self-trade prevention | Changes the ETH_USDT short leverage and sets it back; reads the position mode; reads, creates, changes and deletes a self-trade prevention group; reads a sub-account's leverage and position mode. Accounts that aren't a market maker's get MEXC code 511 for the groups, and keys without that sub-account get a refusal for its reads; the tests report both as known issues. |
| Live orders | **Places orders:** opens and closes a BTC_USDC long; rests a post-only buy 5% below the market, changes it, and cancels every pending BTC_USDC order; places two resting orders in a batch and cancels them (batches need a market maker account; MEXC's refusal is a known issue), cancels another by its external ID, chases a limit buy to the best bid, cancels every pending order in every market, and closes the long the chase may have opened. |
| Live plan, stop and trailing orders | **Places orders:** opens a BTC_USDC long, adds a stop-loss 10% below the market, a trailing close and a plan order that both act only 50% above it, cancels them and closes the long; then, on another long, changes each kind before canceling it, the stop orders by position and the plan orders by market. |
| Live account streams | **Places orders:** opens and closes a BTC_USDC long; then opens another long and, on it, places and cancels a stop order, a trailing order, a plan order and a limit order with attached stops. The account streams are open throughout, and their pushes must decode. |
| Live position changes | **Places orders and changes settings:** opens a BTC_USDC long, adds 1 USDC of margin and removes 0.1, switches automatic margin and back, changes its leverage and sets it back, reverses it into a short and closes every position; the risk limit, liquidation, leverage mode and trial bonus streams stay open and must decode whatever arrives. Then switches the position mode and back, and turns multi-asset mode on and off; the position mode stream must push. |

Set them in the environment, reading them without echo so they stay out of your shell history:

```bash
printf 'API key: ' && read -rs MEXC_API_KEY && echo && printf 'Secret: ' && read -rs MEXC_API_SECRET && echo && export MEXC_API_KEY MEXC_API_SECRET
```

Never put keys in an Xcode scheme's environment variables: a shared scheme is a file that can be committed.

```bash
swift test --filter Live
```

Or, to run them from Xcode without environment variables, create `Tests/MexcKitTestSupport/LocalLiveTestSettings.swift`. Git ignores it; never commit it. Keep the names and types exactly as shown, or the values don't replace the empty defaults and the tests skip:

```swift
extension LocalLiveTestSettings {
    static let apiKey = ""
    static let secret = ""
}
```

A key and secret set in the environment win over the file's; the two are always taken together from one place. Without the file, the package builds and live tests skip. The values are compiled into the build folders (`.build`, DerivedData), so delete those before sharing them.

## Protobuf messages

`Sources/MexcKitProtobuf/Proto/` holds MEXC's `.proto` files unmodified, and `Generated/` beside it is generated from them. Never edit either by hand; update both with the steps in [its README](Sources/MexcKitProtobuf/README.md).

## Commits

Conventional Commits with a short summary, one feature per commit.

## Releases

A pull request's label decides the release when it merges to `main`:

| Label | Release | Example |
|---|---|---|
| `release:patch` | a fix | 1.0.0 to 1.0.1 |
| `release:minor` | a feature | 1.0.0 to 1.1.0 |
| `release:major` | a breaking change | 1.2.3 to 2.0.0 |

A pull request without one releases nothing. A maintainer can also release `main` by hand: run the Release workflow and pick the bump. `.github/workflows/release.yml` works out the version from the latest `X.Y.Z` tag with `.github/scripts/release-version.sh`, builds and tests on macOS and Linux, builds for iOS, tvOS and visionOS and builds the documentation; only when all of them pass does it tag the version, publish a GitHub release whose notes `.github/release.yml` groups by label, and start the Documentation workflow.

The first version, 1.0.0, is tagged by hand on `main`, since the workflow only raises an existing tag:

```bash
git tag -a 1.0.0 -m "MexcKit 1.0.0" && git push origin 1.0.0
```

Then create its GitHub release, and run the Documentation workflow by hand, since nothing else starts it for a tag made by hand.

The repository needs, once:

- The labels `release:patch`, `release:minor`, `release:major` and `bug` (the bug report form adds it).
- Pages set to deploy from GitHub Actions; the `github-pages` environment lets only `main` deploy. Pages on a private repository needs a paid GitHub plan for the organization, so until the repository is public or the plan allows it, the Documentation workflow fails at its deploy job and the docs are built only locally.

`.github/scripts/build-documentation.sh` builds the same site locally into `site/`. It appends the documentation plugin to `Package.swift`, so run it in a clean copy and throw the copy away. It runs docc through `.github/scripts/docc-with-core-comments.py`, which puts `MexcKitCore`'s doc comments back on `MexcKit`'s pages: without it, every core type's page there has no description.
