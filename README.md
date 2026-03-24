# selfauth

**Launch any command with its own macOS TCC identity.**

`selfauth` is a tiny, zero-dependency macOS utility that solves a specific and frustrating problem: CLI tools that silently fail when run inside VS Code, Cursor, or any other Electron-based host because macOS denies their privacy API requests without explanation.

```
selfauth <command> [args...]
```

It is completely transparent -- stdin, stdout, stderr, and exit codes pass through unchanged. If the child process does not need TCC access, `selfauth` is a harmless no-op.

---

## The Problem

macOS enforces privacy permissions through a system called **TCC** (Transparency, Consent, and Control). When your code tries to access Reminders, Calendar, Contacts, the microphone, or any other protected resource, TCC decides whether to allow it.

Here is the catch: TCC does not always ask *your process* for permission. It walks up the process tree to find the **responsible process** -- the app it considers accountable for the request. For processes launched from Terminal.app or iTerm2, this works fine: the terminal disclaims responsibility, so your tool gets its own identity and its own permission dialog.

But when your CLI tool runs as a child of **VS Code, Cursor, or another Electron app**, macOS attributes the TCC request to the Electron host. The Electron app almost certainly does not have (and cannot easily get) a TCC grant for Reminders or Contacts. So macOS **silently denies the request**. No dialog. No error. Your tool just gets empty data or a cryptic failure.

This is not a bug in your tool. It is not a bug in VS Code. It is how macOS TCC attribution works by design.

## The Solution

`selfauth` breaks the attribution chain. It spawns your command using `posix_spawn` with the `responsibility_spawnattrs_setdisclaim` flag, which tells macOS: *"the child process is responsible for itself."* The child gets its own TCC identity, macOS shows permission dialogs attributed to it, and grants are remembered for future runs.

This is the same mechanism that terminal emulators like iTerm2, Ghostty, and Kitty use internally. `selfauth` just makes it available as a standalone wrapper so any host process can benefit from it.

---

## Installation

### Build from source

```bash
git clone https://github.com/MarqueIV/selfauth.git
cd selfauth
swift build -c release
```

The binary lands at `.build/release/selfauth`.

### Copy to PATH

```bash
sudo cp .build/release/selfauth /usr/local/bin/
```

Or anywhere else on your `PATH`.

### Universal binary (arm64 + x86_64)

If you need a fat binary that runs natively on both Apple Silicon and Intel:

```bash
swiftc -target arm64-apple-macosx14.0 Sources/selfauth/main.swift -o /tmp/selfauth-arm64
swiftc -target x86_64-apple-macosx14.0 Sources/selfauth/main.swift -o /tmp/selfauth-x86_64
lipo -create /tmp/selfauth-arm64 /tmp/selfauth-x86_64 -output selfauth
sudo cp selfauth /usr/local/bin/
```

---

## Usage

Prefix any command with `selfauth`:

```bash
# Access Apple Reminders from inside VS Code
selfauth iclaude reminders list

# Access Contacts
selfauth /usr/local/bin/contacts-tool search "Jane"

# Any PATH-resolved binary works
selfauth my-calendar-tool --today

# Arguments pass through exactly as-is
selfauth my-tool --flag value --verbose
```

On the **first run** of a given command through `selfauth`, macOS will show a permission dialog attributed to that command (not to VS Code or your Electron host). Once you grant access, subsequent runs work without prompting.

---

## When You Need It

| Scenario | Need `selfauth`? |
|---|---|
| CLI tool run from **Terminal.app** | No -- Terminal already disclaims responsibility |
| CLI tool run from **iTerm2 / Ghostty / Kitty** | No -- these terminals disclaim responsibility |
| CLI tool run from **VS Code integrated terminal** | **Yes** |
| CLI tool run from **Cursor** | **Yes** |
| CLI tool run from any **Electron app** | **Yes** |
| CLI tool run from a **CI pipeline / ssh session** | No -- TCC is not involved without a GUI context |
| CLI tool that does not use privacy APIs | No -- but `selfauth` is a harmless passthrough, so it does not matter |

The safe default: if you are unsure whether your execution context needs it, just use `selfauth`. It adds no overhead and never changes behavior for tools that do not need TCC access.

---

## How It Works

The entire implementation is a single Swift file (~80 lines). Here is what it does:

1. **Resolves the target binary** -- handles both absolute/relative paths and `PATH` lookup.
2. **Initializes `posix_spawn` attributes** with `responsibility_spawnattrs_setdisclaim` set to `1`. This is an undocumented but stable Apple API that marks the child process as its own responsible process for TCC purposes.
3. **Calls `posix_spawn`** to launch the child. Because no file actions are specified, the child inherits stdin, stdout, and stderr from the parent.
4. **Waits for the child** via `waitpid` and forwards its exit code.

The `responsibility_spawnattrs_setdisclaim` API is private but widely relied upon. It is used by every major third-party terminal emulator on macOS and has been stable across macOS releases. The function is accessed via `@_silgen_name` to avoid needing private headers.

---

## Exit Codes

`selfauth` forwards the child process's exit code. It also uses standard conventions for its own errors:

| Code | Meaning |
|---|---|
| `1` | No command provided, or spawn failed |
| `126` | Command found but not executable |
| `127` | Command not found |

---

## Companion Projects

[**iClaude**](https://github.com/MarqueIV/iClaude) -- A Swift CLI for managing Apple Reminders and Calendar, designed for AI agents. Uses `selfauth` to ensure reliable access to privacy-protected EventKit and Reminders APIs regardless of the host process.

---

## Requirements

- macOS 14.0 (Sonoma) or later
- Swift 5.9+ (for building from source only)

## License

MIT -- see [LICENSE](LICENSE) for details.
