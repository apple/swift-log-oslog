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

/// A terminal handler that consumes the (possibly redacted) metadata through `blackHole`, so the redaction work on
/// the way in cannot be optimized away.
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

/// Builds `count` metadata entries, the first `publicOutOf` tagged `.public` (passed through) and the rest
/// `.sensitive` (redacted). `publicOutOf == count` → nothing is redacted; `publicOutOf == 0` → everything is.
func makeMetadata(count: Int, publicOutOf: Int) -> Logger.Metadata {
    var metadata = Logger.Metadata()
    for i in 0..<count {
        let value = "value-\(i)"
        metadata["key-\(i)"] = i < publicOutOf ? "\(value, sensitivity: .public)" : "\(value, sensitivity: .sensitive)"
    }
    return metadata
}

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

public let benchmarks: @Sendable () -> Void = {
    // Instructions + allocations; allocation count is the headline, so a regression that reintroduces a redundant copy
    // shows up immediately. Built here rather than as a global `let` because `Benchmark.Configuration` is not Sendable.
    let redactionConfig = Benchmark.Configuration(
        metrics: [.instructions, .objectAllocCount],
        maxIterations: 100_000
    )
    let redactionLogHandler = RedactionLogHandler(mode: .redacting, wrapping: SinkLogHandler())

    // Sweep how much of a 4-entry metadata is sensitive: none, half, all.
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
