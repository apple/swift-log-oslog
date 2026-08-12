//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Logging API open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift Logging API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Logging API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Benchmark
import Logging
import OSLogHandler
import SensitivityAttribute

// No `import os` here, so `Logger` unambiguously means swift-log's `Logger`.

/// A `Logger` backed by `OSLogHandler`, with `logLevel` pinned to `.info` so every benchmark measures the enabled
/// path deterministically regardless of the machine's current unified-logging configuration.
private func makeBridgeLogger(category: String, base: Logger.Metadata = [:]) -> Logger {
    var handler = OSLogHandler(subsystem: "com.example.applelogbench", category: category)
    for (key, value) in base {
        handler[metadataKey: key] = value
    }
    var logger = Logger(label: category) { _ in handler }
    logger.logLevel = .info
    return logger
}

/// The swift-log -> OSLogHandler bridge, as a cost ladder over the pure baseline.
func bridgeBenchmarks(configuration: Benchmark.Configuration) {
    // Constant message, no metadata — swift-log's base wrapping cost.
    let noMetadata = makeBridgeLogger(category: "bridge-nometa")
    Benchmark("bridge_no_metadata", configuration: configuration) { _ in
        noMetadata.info("req")
    }

    // Emission-time metadata — allocates a Logger.Metadata dictionary and partitions it on every call.
    let emissionTime = makeBridgeLogger(category: "bridge-emission")
    Benchmark("bridge_emission_time_metadata", configuration: configuration) { _ in
        emissionTime.info("req", metadata: ["id": "\(42, sensitivity: .public)"])
    }

    // The field set on the handler once (base metadata), with emission-time calls carrying nothing — so OSLogHandler
    // reuses its cached base-metadata partition: no per-call dictionary allocation and no re-partition. Compare against
    // `bridge_emission_time_metadata` to see what that cache buys.
    let baseMetadata: Logger.Metadata = ["id": "\(42, sensitivity: .public)"]
    let withBaseMetadata = makeBridgeLogger(category: "bridge-base", base: baseMetadata)
    Benchmark("bridge_base_metadata", configuration: configuration) { _ in
        withBaseMetadata.info("req")
    }

    // Base context AND an emission-time field on the same log — the case where the base partition is combined with the
    // emission-time partition, so the cached base string is copied to append the emission-time part.
    let baseContext: Logger.Metadata = ["ctx": "\(1, sensitivity: .public)"]
    let withBaseAndEmission = makeBridgeLogger(category: "bridge-both", base: baseContext)
    Benchmark("bridge_base_and_emission_metadata", configuration: configuration) { _ in
        withBaseAndEmission.info("req", metadata: ["id": "\(42, sensitivity: .public)"])
    }

    // A large accumulated base (what a long-lived `withLogger(mergingMetadata:)` scope accrues) plus one emission-time
    // field per log — measures how the per-emission base+emission cost (the cached base string is copied to append the
    // emission-time part) grows with base size.
    var largeBase = Logger.Metadata()
    for i in 0..<24 {
        largeBase["ctx-\(i)"] = "\("value-\(i)", sensitivity: .public)"
    }
    let withLargeBase = makeBridgeLogger(category: "bridge-large-base", base: largeBase)
    Benchmark("bridge_large_base_and_emission_metadata", configuration: configuration) { _ in
        withLargeBase.info("req", metadata: ["id": "\(42, sensitivity: .public)"])
    }

    // The end-to-end scope: `withLogger(mergingMetadata:)` accrues the large base once, then multiple statements emit
    // within it (each with an emission-time field). Captures the scope setup (the merge re-flattens the cache per key)
    // amortized over the emissions, and multiplies the per-emission base+emission cost by the statement count.
    let scopeLogger = makeBridgeLogger(category: "bridge-scope")
    Benchmark("bridge_scope_large_base_multiple_emissions", configuration: configuration) { _ in
        withLogger(scopeLogger) { _ in
            withLogger(mergingMetadata: largeBase) { logger in
                for _ in 0..<10 {
                    logger.info("req", metadata: ["id": "\(42, sensitivity: .public)"])
                }
            }
        }
    }
}
