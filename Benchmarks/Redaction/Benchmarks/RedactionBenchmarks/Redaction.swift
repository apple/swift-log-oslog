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
import SensitivityAttribute

// MARK: - Support handlers

/// A terminal handler that passes the event metadata to `blackHole`, so the compiler cannot remove the redaction
/// work.
struct SinkLogHandler: LogHandler {
    var logLevel: Logger.Level = .trace
    var metadata: Logger.Metadata = [:]
    var metadataProvider: Logger.MetadataProvider?
    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { self.metadata[key] }
        set { self.metadata[key] = newValue }
    }
    func log(event: LogEvent) {
        blackHole(event.metadata)
    }
}

// MARK: - Fixtures

/// Creates metadata with `count` entries. The first `publicOutOf` entries are `.public`. The others are
/// `.sensitive`.
///
/// - Parameters:
///   - count: The number of entries.
///   - publicOutOf: The number of `.public` entries.
func makeMetadata(count: Int, publicOutOf: Int) -> Logger.Metadata {
    var metadata = Logger.Metadata()
    for i in 0..<count {
        let value = "value-\(i)"
        metadata["key-\(i)"] = i < publicOutOf ? "\(value, sensitivity: .public)" : "\(value, sensitivity: .sensitive)"
    }
    return metadata
}

/// Creates a log event with the given metadata.
///
/// - Parameter metadata: The metadata of the event.
func makeEvent(metadata: Logger.Metadata) -> LogEvent {
    LogEvent(
        level: .info,
        message: "request handled",
        metadata: metadata,
        source: "benchmarks",
        file: #fileID,
        function: #function,
        line: #line
    )
}

// MARK: - Benchmarks

/// Registers the `RedactionLogHandler` benchmarks.
public let benchmarks: @Sendable () -> Void = {
    let redactionConfig = Benchmark.Configuration(
        metrics: [.instructions, .objectAllocCount],
        maxIterations: 100_000,
        thresholds: [
            .instructions: BenchmarkThresholds(
                relative: [
                    .p90: 10.0  // we only record p90
                ]
            ),
            .objectAllocCount: BenchmarkThresholds(
                absolute: [
                    .p90: 0  // we only record p90
                ]
            ),
        ]
    )
    let redactionLogHandler = RedactionLogHandler(wrapping: SinkLogHandler())

    // Vary the number of sensitive entries in a 4-entry metadata: none, half, all.
    let allPublicEvent = makeEvent(metadata: makeMetadata(count: 4, publicOutOf: 4))
    let mixedEvent = makeEvent(metadata: makeMetadata(count: 4, publicOutOf: 2))
    let allSensitiveEvent = makeEvent(metadata: makeMetadata(count: 4, publicOutOf: 0))

    Benchmark("redacting_0_of_4", configuration: redactionConfig) { _ in
        redactionLogHandler.log(event: allPublicEvent)
    }
    Benchmark("redacting_2_of_4", configuration: redactionConfig) { _ in
        redactionLogHandler.log(event: mixedEvent)
    }
    Benchmark("redacting_4_of_4", configuration: redactionConfig) { _ in
        redactionLogHandler.log(event: allSensitiveEvent)
    }
}
