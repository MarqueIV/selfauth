import Darwin
import Foundation

/// Launches any command with its own macOS TCC identity.
///
/// When a CLI tool runs as a child of an Electron app (VS Code, Cursor, etc.),
/// macOS attributes TCC permission requests to the parent app and silently denies
/// them. This tool uses `responsibility_spawnattrs_setdisclaim` to break that chain,
/// letting the spawned process handle its own TCC permissions.
///
/// Usage: selfauth <command> [args...]
///   e.g. selfauth .build/debug/iclaude lists
///        selfauth /usr/local/bin/mytool --flag value

@_silgen_name("responsibility_spawnattrs_setdisclaim")
func responsibility_spawnattrs_setdisclaim(
    _ attrs: UnsafeMutablePointer<posix_spawnattr_t?>,
    _ disclaim: Int32
) -> Int32

guard CommandLine.arguments.count >= 2 else {

    fputs("Usage: selfauth <command> [args...]\n", stderr)
    fputs("Launches <command> with its own TCC identity.\n", stderr)
    exit(1)
}

// Resolve the target binary
let rawPath = CommandLine.arguments[1]
let binaryPath: String

if rawPath.contains("/") {
    binaryPath = (rawPath as NSString).standardizingPath
} else {
    // Search PATH
    let pathDirs = (ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/usr/local/bin")
        .split(separator: ":")
        .map(String.init)
    guard let found = pathDirs
        .map({ ($0 as NSString).appendingPathComponent(rawPath) })
        .first(where: { FileManager.default.isExecutableFile(atPath: $0) })
    else {
        fputs("selfauth: command not found: \(rawPath)\n", stderr)
        exit(127)
    }
    binaryPath = found
}

guard FileManager.default.isExecutableFile(atPath: binaryPath) else {

    fputs("selfauth: not executable: \(binaryPath)\n", stderr)
    exit(126)
}

// Build argv for the child: [binaryPath, arg1, arg2, ...]
let childArgs = [binaryPath] + Array(CommandLine.arguments.dropFirst(2))
let cArgs: [UnsafeMutablePointer<CChar>?] = childArgs.map { strdup($0) } + [nil]
defer { cArgs.compactMap { $0 }.forEach { free($0) } }

// Set up spawn attributes — disclaim responsibility so child owns its TCC
var attrs: posix_spawnattr_t? = nil
posix_spawnattr_init(&attrs)
_ = responsibility_spawnattrs_setdisclaim(&attrs, 1)

// Spawn — inherits stdin/stdout/stderr automatically
var pid: pid_t = 0
let result = binaryPath.withCString { path in

    posix_spawn(&pid, path, nil, &attrs, cArgs, environ)
}
posix_spawnattr_destroy(&attrs)

guard result == 0 else {

    fputs("selfauth: failed to spawn \(binaryPath): \(String(cString: strerror(result)))\n", stderr)
    exit(1)
}

// Wait for child and forward its exit code
var status: Int32 = 0
waitpid(pid, &status, 0)

let exitCode: Int32 = (status & 0x7f) == 0 ? (status >> 8) & 0xff : 1
exit(exitCode)
