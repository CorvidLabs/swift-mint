// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swift-mint",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "Mint",
            targets: ["Mint"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/CorvidLabs/swift-algorand", from: "0.1.0"),
        .package(url: "https://github.com/CorvidLabs/swift-pinata", from: "0.1.0"),
    ],
    targets: [
        .target(
            name: "Mint",
            dependencies: [
                .product(name: "Algorand", package: "swift-algorand"),
                .product(name: "Pinata", package: "swift-pinata"),
            ]
        ),
        .testTarget(
            name: "MintTests",
            dependencies: ["Mint"]
        ),
    ]
)
