## What changed and why



## Checklist

- [ ] `swift format lint --strict -r Sources/MexcKit Sources/MexcKitCore Tests Package.swift` passes.
- [ ] `swift build --build-tests -Xswiftc -warnings-as-errors` and `swift test` pass in a clean copy, without the local live test settings file.
- [ ] New behavior has tests, and new responses and pushes have fixtures: recorded from MEXC, or MEXC's documented examples until one is.
- [ ] The live suites that cover a changed endpoint or stream passed on a maintainer's machine, or the description says why they didn't run.
- [ ] New public symbols have DocC comments where their names don't carry the meaning, and changed examples match `Tests/MexcKitTests/PublicAPI/DocumentationExamples.swift`.
- [ ] `Sources/MexcKitProtobuf/Proto` and `Generated` change only as the README in `Sources/MexcKitProtobuf` says.
- [ ] No API key, secret or signature appears in the code, a fixture, a log or this description.
- [ ] A maintainer adds `release:patch`, `release:minor` or `release:major` to release this change on merge.
