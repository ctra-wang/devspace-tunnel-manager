// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DevSpaceTunnelManager",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DevSpaceTunnelManager", targets: ["DevSpaceTunnelManager"])
    ],
    targets: [
        .executableTarget(
            name: "DevSpaceTunnelManager",
            path: "Sources/DevSpaceTunnelManager"
        )
    ]
)
