// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SharedKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "SharedKit", targets: ["SharedKit"]),
        .executable(name: "appdropctl", targets: ["AppDropCtl"])
    ],
    targets: [
        .target(
            name: "SharedKit",
            path: "Sources/SharedKit",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "AppDropCtl",
            dependencies: ["SharedKit"],
            path: "Sources/AppDropCtl"
        ),
        .testTarget(
            name: "SharedKitTests",
            dependencies: ["SharedKit"],
            path: "Tests/SharedKitTests"
        )
    ]
)

