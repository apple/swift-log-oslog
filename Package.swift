// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "swift-log-oslog",
    products: [
        .library(name: "SensitivityAttribute", targets: ["SensitivityAttribute"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0")
    ],
    targets: [
        .target(
            name: "SensitivityAttribute",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ],
            exclude: ["SensitivityAttribute.docc"]
        ),
        .testTarget(
            name: "SensitivityAttributeTests",
            dependencies: [
                "SensitivityAttribute",
                .product(name: "InMemoryLogging", package: "swift-log"),
            ],
        ),
    ]
)
