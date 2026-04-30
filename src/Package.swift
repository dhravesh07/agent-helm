// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AgentHelm",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AgentHelm", targets: ["AgentHelm"])
    ],
    dependencies: [
        .package(url: "https://github.com/orlandos-nl/Citadel.git", from: "0.12.1"),
    ],
    targets: [
        .executableTarget(
            name: "AgentHelm",
            dependencies: [
                .product(name: "Citadel", package: "Citadel"),
            ],
            path: "Sources/AgentHelm",
            exclude: [
                "Info.plist",
                "AgentHelm.entitlements",
            ]
        ),
        .testTarget(
            name: "AgentHelmTests",
            dependencies: ["AgentHelm"],
            path: "Tests/AgentHelmTests"
        )
    ]
)
