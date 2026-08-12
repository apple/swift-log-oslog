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

// `os` (Apple's unified logging) and `Logging` (swift-log) both export a `Logger` type, so importing them in the same
// file makes `Logger` ambiguous. The pure and bridge benchmarks live in separate files with disjoint imports; this
// file wires them together.
public let benchmarks: @Sendable () -> Void = {
    // Built here, not as a global `let`, because `Benchmark.Configuration` is not Sendable.
    let configuration = Benchmark.Configuration(
        metrics: [.instructions, .objectAllocCount],
        maxIterations: 100_000
    )
    pureBenchmarks(configuration: configuration)
    bridgeBenchmarks(configuration: configuration)
}
