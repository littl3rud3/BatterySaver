// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BatterySaver",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "BatterySaver", targets: ["BatterySaver"])
    ],
    targets: [
        .executableTarget(
            name: "BatterySaver",
            path: "Sources/BatterySaver",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
