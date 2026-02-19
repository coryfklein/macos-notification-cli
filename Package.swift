// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "notif",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "NotifCore",
            path: "Sources/NotifCore"
        ),
        .executableTarget(
            name: "notif",
            dependencies: [
                "NotifCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/notif"
        ),
        .executableTarget(
            name: "notif-test-unit",
            dependencies: ["NotifCore"],
            path: "Tests/Unit"
        ),
    ]
)
