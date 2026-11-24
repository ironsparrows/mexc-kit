# Contributing

Read [ARCHITECTURE.md](ARCHITECTURE.md) first: it lists the targets, the access rules and the words the code uses.

## Requirements

Swift 6.4 or later. On macOS, Xcode 27.2 or later for the iOS build.

Supported platforms: macOS 13, iOS 16, tvOS 16, visionOS 1 and Linux. watchOS is not supported.

## Checks before a change lands

Run them in a clean copy of the repository, so a local settings file and its keys never take part:

```bash
copy=$(mktemp -d) && git ls-files -z --cached --others --exclude-standard | rsync -a --from0 --files-from=- ./ "$copy"/ && cd "$copy"
```

Git ignores the local settings file, so the copy never has it. Each run makes a new copy, so files you deleted or renamed don't linger. Stage a deleted tracked file (`git rm`) first: the copy stops at a listed file that is missing.

Then, from the copy:

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

Linux is a supported platform but has no local check yet. `swift build` and `swift test` on Linux are unverified until CI or a Linux machine runs them, including the `MexcKitTestSupport` target, which imports Testing.

## Tests

- Swift Testing only, one `@Suite` per file, named after the suite.
- Unit tests run offline. A live test calls MEXC's servers: give its suite `.tags(.live)`, `.enabled(if: areLiveTestsEnabled, "Set MEXC_API_KEY and MEXC_API_SECRET to run")` and `.timeLimit(.minutes(2))`, and build its client with `MexcFutures.Client(credentials: LiveTestSettings.credentials)`. Both come from `MexcKitTestSupport`.
- Never put an API key or secret in a committed file, a fixture or a log.

### Running live tests

Live tests run when an API key and its secret are set; otherwise they skip. There is no other switch. They call MEXC with that key and account, and live tests that place small real orders run with it too, so use a key and an account you accept that for.

Set them in the environment, reading them without echo so they stay out of your shell history:

```bash
read -rs "MEXC_API_KEY?API key: " && read -rs "MEXC_API_SECRET?Secret: " && export MEXC_API_KEY MEXC_API_SECRET
```

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

## Commits

Conventional Commits with a short summary, one feature per commit.
