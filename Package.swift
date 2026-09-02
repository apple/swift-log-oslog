// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "swift-log-oslog",
    products: [
        .library(
            name: "swift_log_oslog",
            targets: ["swift_log_oslog"]
        ),
    ],
    targets: [
        .target(
            name: "swift_log_oslog",
        ),
        .testTarget(
            name: "swift_log_oslogTests",
            dependencies: ["swift_log_oslog"],
        ),
    ]
)
