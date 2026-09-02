// swift-tools-version:6.2
//===----------------------------------------------------------------------===//
//
// package-benchmark suite for swift-log-oslog. Uses Ordo One's `Benchmark`
// (https://github.com/ordo-one/package-benchmark), mirroring swift-log's own Benchmarks setup, to measure
// allocations and instructions deterministically instead of wall-clock time.
//
// Run from this directory:
//   swift package --disable-sandbox --allow-writing-to-package-directory benchmark
//
//===----------------------------------------------------------------------===//

import PackageDescription

let package = Package(
    name: "RedactionBenchmarks",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        // swift-log-oslog (this package's parent), providing RedactionLogHandler and the Sensitivity API.
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
