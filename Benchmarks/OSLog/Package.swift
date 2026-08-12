// swift-tools-version:6.2
//===----------------------------------------------------------------------===//
//
// package-benchmark suite for the swift-log -> OSLogHandler bridge. Mirrors the Redaction suite and swift-log's
// Benchmarks setup. Measures *instructions* and *allocations* (the deterministic, in-process cost of the bridge),
// not wallclock — os_log's own work is asynchronous and out-of-process, so instruction/allocation counts isolate the
// overhead swift-log adds over a native os_log call.
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
        // swift-apple-log (this package's parent): the OSLogHandler bridge + the Sensitivity API.
        .package(path: "../.."),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.14.0"),
        .package(url: "https://github.com/ordo-one/benchmark.git", from: "1.35.0"),
    ],
    targets: [
        .executableTarget(
            name: "OSLogBenchmarks",
            dependencies: [
                .product(name: "Benchmark", package: "benchmark"),
                .product(name: "OSLogHandler", package: "swift-apple-log"),
                .product(name: "SensitivityAttribute", package: "swift-apple-log"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Benchmarks/OSLogBenchmarks",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "benchmark")
            ]
        )
    ]
)
