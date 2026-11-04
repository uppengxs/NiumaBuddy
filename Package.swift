// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "NiumaBuddy",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "NiumaBuddy",
            path: "Sources/NiumaBuddy"
        )
    ]
)
