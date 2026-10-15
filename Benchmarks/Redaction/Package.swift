// swift-tools-version:6.2

import PackageDescription

let package = Package(
    name: "RedactionBenchmarks",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        // The parent package. It provides RedactionLogHandler and the Sensitivity API.
        .package(path: "../.."),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.14.0"),
        .package(url: "https://github.com/ordo-one/benchmark.git", from: "1.35.0"),
    ],
    targets: [
        .executableTarget(
            name: "RedactionBenchmarks",
            dependencies: [
                .product(name: "Benchmark", package: "benchmark"),
                .product(name: "SensitivityAttribute", package: "swift-log-oslog"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Benchmarks/RedactionBenchmarks",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "benchmark")
            ]
        )
    ]
)
