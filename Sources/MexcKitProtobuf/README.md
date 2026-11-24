# MexcKitProtobuf

Swift messages for MEXC's futures WebSocket in Protobuf mode (`wss://contract.mexc.com/edge?Trans-Protocol=Protobuf`). Every binary push frame is one `ContractWrapper`.

- `Proto/`: MEXC's `.proto` files and their Apache 2.0 `LICENSE`, copied unmodified from [mexcdevelop/websocket-future-proto](https://github.com/mexcdevelop/websocket-future-proto), directory `proto/`, at commit `033825833318b4bc3add4481997e9f76005c6483` (2026-10-22).
- `Generated/`: the Swift that swift-protobuf 1.41.0 generates from them. Don't edit it by hand.

The messages have `package` access: only this package's targets see them, never an app.

## Regenerating

Do this when MEXC changes its `.proto` files. Build `protoc` and `protoc-gen-swift` from swift-protobuf 1.41.0, the version that generated `Generated/`, so no system-wide `protoc` is needed. Run the commands in one shell: the first sets `tools`.

```bash
tools="${TMPDIR:-/tmp}/swift-protobuf" && rm -rf "$tools" && git clone --depth 1 --branch 1.41.0 https://github.com/apple/swift-protobuf.git "$tools"
```

```bash
swift build -c release --package-path "$tools" --product protoc && swift build -c release --package-path "$tools" --product protoc-gen-swift
```

Replace the files in `Proto/` with upstream's `proto/*.proto` and `LICENSE`, unchanged, so a file MEXC deleted or renamed doesn't linger. Then, from the repository root:

```bash
rm Sources/MexcKitProtobuf/Generated/*.pb.swift && "$tools/.build/release/protoc" \
  --plugin=protoc-gen-swift="$tools/.build/release/protoc-gen-swift" \
  --swift_opt=Visibility=Package --swift_opt=UseAccessLevelOnImports=true --swift_opt=FileNaming=DropPath \
  --proto_path=Sources/MexcKitProtobuf/Proto --swift_out=Sources/MexcKitProtobuf/Generated \
  Sources/MexcKitProtobuf/Proto/*.proto
```

- `Visibility=Package` gives the messages `package` access.
- `UseAccessLevelOnImports=true` writes `package import SwiftProtobuf`. Without it the files don't compile under `InternalImportsByDefault`.
- `FileNaming=DropPath` names each file after its `.proto`.

Update the commit and its date above in the same change. `Package.swift` requires swift-protobuf `from: "1.41.0"`: the generator's version or later, as swift-protobuf's plugin documentation recommends. Generated code checks only the runtime's API generation when it compiles (`ProtobufAPIVersion_2`), so a newer 1.x runtime works with it. To generate with a newer swift-protobuf, raise that lowest version to the generator's in the same change.
