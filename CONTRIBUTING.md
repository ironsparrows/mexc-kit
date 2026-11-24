# Contributing

Read [ARCHITECTURE.md](ARCHITECTURE.md) first: it lists the targets, the access rules and the words the code uses.

## Requirements

Swift 6.4 or later. On macOS, Xcode 27.2 or later for the iOS build.

Supported platforms: macOS 13, iOS 16, tvOS 16, visionOS 1 and Linux. watchOS is not supported.

## Checks before a change lands

Run them from the package root:

```bash
swift build --build-tests -Xswiftc -warnings-as-errors
```

```bash
swift test
```

```bash
xcodebuild build -scheme MexcKit -destination 'generic/platform=iOS'
```

`-Xswiftc -warnings-as-errors` applies to this package's targets only: SwiftPM compiles dependencies with their warnings suppressed.

Linux is a supported platform but has no local check yet. `swift build` and `swift test` on Linux are unverified until CI or a Linux machine runs them.

## Tests

- Swift Testing only, one `@Suite` per file, named after the suite.
- Unit tests run offline. Tag tests against the live MEXC servers `.live` and skip them unless `MEXC_LIVE=1` is set; private ones also need a key in the environment.
- Never put an API key or secret in a file, fixture or log.

## Commits

Conventional Commits with a short summary, one feature per commit.
