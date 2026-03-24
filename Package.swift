// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "selfauth",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "selfauth",
            path: "Sources/selfauth"
        ),
    ]
)
