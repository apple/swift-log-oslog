// swift-tools-version:6.2
//===----------------------------------------------------------------------===//
//
// package-benchmark suite for the swift-log to OSLogHandler bridge. Mirrors the Redaction suite and
// swift-log's own Benchmarks setup. Measures instructions and allocations: the deterministic, in-process
// cost of the bridge, not wall-clock time. os_log's own work runs asynchronously and out-of-process, so
// instruction and allocation counts isolate the overhead swift-log adds over a native os_log call.
//
// Run from this directory:
//   swift package --disable-sandbox --allow-writing-to-package-directory benchmark
//
//===----------------------------------------------------------------------===//

import PackageDescription

let package = Package(
    name: "OSLogBenchmarks",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        // swift-log-oslog (this package's parent): the OSLogHandler bridge and the Sensitivity API.
        .package(path: "../.."),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.14.0"),
        .package(url: "https://github.com/ordo-one/benchmark.git", from: "1.35.0"),
    ],
    targets: [
        .executableTarget(
            name: "OSLogBenchmarks",
            dependencies: [
                .product(name: "Benchmark", package: "benchmark"),
                .product(name: "OSLogHandler", package: "swift-log-oslog"),
                .product(name: "SensitivityAttribute", package: "swift-log-oslog"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Benchmarks/OSLogBenchmarks",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "benchmark")
            ]
        )
    ]
)
