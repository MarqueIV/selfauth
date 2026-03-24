# selfauth

A macOS utility that launches any command with its own TCC (Transparency, Consent, and Control) identity.

## The Problem

When a CLI tool runs as a child process of an Electron app (VS Code, Cursor, etc.), macOS attributes TCC permission requests to the parent app and silently denies them. Your tool never gets a permission dialog — it just fails.

This affects any CLI that needs access to privacy-protected APIs: Reminders, Calendars, Contacts, Camera, Microphone, etc.

## The Solution

`selfauth` uses macOS's `responsibility_spawnattrs_setdisclaim` API to break the TCC attribution chain. The spawned process becomes its own "responsible process," so macOS prompts for (and remembers) permissions under the tool's own identity.

```
selfauth <command> [args...]
```

stdin, stdout, and stderr pipe through transparently. Exit codes are forwarded.

## Examples

```bash
# Run a Reminders CLI from VS Code's terminal
selfauth ./my-reminders-tool lists

# Run any TCC-protected tool
selfauth /usr/local/bin/contacts-cli search "John"

# Works with any path or PATH-resolved binary
selfauth my-tool --flag value
```

On first run, macOS will show a permission dialog attributed to the launched command (not to VS Code). Once granted, subsequent runs work without prompting.

## Installation

### Build from source

```bash
swift build -c release
cp .build/release/selfauth /usr/local/bin/
```

### Universal binary (arm64 + x86_64)

```bash
swiftc -target arm64-apple-macosx14.0 Sources/selfauth/main.swift -o /tmp/selfauth-arm64
swiftc -target x86_64-apple-macosx14.0 Sources/selfauth/main.swift -o /tmp/selfauth-x86_64
lipo -create /tmp/selfauth-arm64 /tmp/selfauth-x86_64 -output selfauth
```

### Add to PATH

Copy `selfauth` to a directory in your PATH:

```bash
cp selfauth /usr/local/bin/
```

## How It Works

macOS TCC determines a "responsible process" for privacy permission requests by walking up the process tree. For Electron apps (VS Code, Cursor), child processes get attributed to the Electron app, which typically lacks specific TCC grants.

`selfauth` calls `posix_spawn` with the private (but widely-used) `responsibility_spawnattrs_setdisclaim` flag. This tells macOS the spawned process is responsible for itself. Terminal emulators like iTerm2 and Ghostty use this same mechanism.

## Requirements

- macOS 14.0 (Sonoma) or later
- Swift 5.9 or later (for building from source)

## License

MIT
