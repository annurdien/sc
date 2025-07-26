// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "sc",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "sc", targets: ["SC"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        .package(url: "https://github.com/onevcat/Rainbow", from: "4.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "SC",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Yams", package: "Yams"),
                .product(name: "Rainbow", package: "Rainbow"),
            ],
            path: "Sources/SC"
        ),
        .testTarget(
            name: "SCTests",
            dependencies: ["SC"],
            path: "Tests/SCTests"
        ),
    ]
)
