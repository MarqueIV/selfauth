# selfauth

macOS utility that launches any command with its own TCC identity by disclaiming
the parent process's responsibility. Single Swift file, no dependencies.

## Why This Exists

Electron apps (VS Code, Cursor) silently deny TCC permission requests from child
processes. This tool uses `responsibility_spawnattrs_setdisclaim` via `posix_spawn`
to break that attribution chain, letting the spawned command handle its own TCC.

## Build

```
swift build
```

## Universal binary

```
swiftc -target arm64-apple-macosx14.0 Sources/selfauth/main.swift -o /tmp/selfauth-arm64
swiftc -target x86_64-apple-macosx14.0 Sources/selfauth/main.swift -o /tmp/selfauth-x86_64
lipo -create /tmp/selfauth-arm64 /tmp/selfauth-x86_64 -output selfauth
```

## Usage

```
selfauth <command> [args...]
```
