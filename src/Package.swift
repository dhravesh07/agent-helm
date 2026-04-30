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
        // SSH client (pure Swift)
        // Pinned later; uncomment once we wire SSH in v0.1.
        // .package(url: "https://github.com/orlandos-nl/Citadel.git", from: "0.7.0"),

        // SQLite via GRDB
        // .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0"),

        // ViewInspector for SwiftUI tests
        // .package(url: "https://github.com/nalexn/ViewInspector.git", from: "0.10.0"),
    ],
    targets: [
        .executableTarget(
            name: "AgentHelm",
            dependencies: [
                // .product(name: "Citadel", package: "Citadel"),
                // .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/AgentHelm"
        ),
        .testTarget(
            name: "AgentHelmTests",
            dependencies: [
                "AgentHelm",
                // .product(name: "ViewInspector", package: "ViewInspector"),
            ],
            path: "Tests/AgentHelmTests"
        )
    ]
)
