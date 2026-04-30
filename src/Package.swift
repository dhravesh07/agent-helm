// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Rookery",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Rookery", targets: ["Rookery"])
    ],
    dependencies: [
        .package(url: "https://github.com/orlandos-nl/Citadel.git", from: "0.12.1"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.1"),
    ],
    targets: [
        .executableTarget(
            name: "Rookery",
            dependencies: [
                .product(name: "Citadel", package: "Citadel"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
            ],
            path: "Sources/Rookery",
            exclude: [
                "Info.plist",
                "Rookery.entitlements",
            ]
        ),
        .testTarget(
            name: "RookeryTests",
            dependencies: ["Rookery"],
            path: "Tests/RookeryTests"
        )
    ]
)
