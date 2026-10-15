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

// `os` and `Logging` both export a `Logger` type. The pure and bridge benchmarks live in separate files with
// disjoint imports to avoid the clash.

/// Registers the `os.Logger` and `OSLogHandler` benchmarks.
///
/// The benchmarks count the instructions and allocations of this process. They do not count os_log work in
/// other processes.
public let benchmarks: @Sendable () -> Void = {
    // Built here, not as a global `let`, because `Benchmark.Configuration` is not Sendable.
    let configuration = Benchmark.Configuration(
        metrics: [.instructions, .objectAllocCount],
        maxIterations: 100_000
    )
    pureBenchmarks(configuration: configuration)
    bridgeBenchmarks(configuration: configuration)
}
