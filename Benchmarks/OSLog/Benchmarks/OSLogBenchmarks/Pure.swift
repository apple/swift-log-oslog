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
import os

/// Registers the benchmarks that log through `os.Logger` without swift-log.
///
/// - Parameter configuration: The measurement settings shared by all benchmarks.
func pureBenchmarks(configuration: Benchmark.Configuration) {
    // A constant message and a native integer argument.
    let osLogger = os.Logger(subsystem: "com.example.applelogbench", category: "pure")
    Benchmark("pure_oslog", configuration: configuration) { _ in
        osLogger.info("req \(42, privacy: .public)")
    }

    // A runtime `String` as a dynamic `%{public}s` argument. The string comes from the process arguments, so the
    // compiler cannot fold it.
    let dynamicMessage = CommandLine.arguments.first ?? "req"
    Benchmark("pure_oslog_dynamic_string", configuration: configuration) { _ in
        osLogger.log(level: .info, "\(dynamicMessage, privacy: .public)")
    }

    // The `os.Logger` equivalent of `bridge_scope_large_base_multiple_emissions`. `os.Logger` has no scoped
    // metadata, so each of the 10 log calls repeats the 24 context fields and passes `id`. All values come from
    // runtime data, so the compiler cannot fold them. os_log can truncate the rendered line. The benchmark
    // measures the packing of the arguments.
    let ctx = (0..<24).map { "value-\($0)" }
    let id = CommandLine.arguments.count
    Benchmark("pure_oslog_repeated_context_multiple_emissions", configuration: configuration) { _ in
        for _ in 0..<10 {
            osLogger.info(
                "req \(ctx[0], privacy: .public) \(ctx[1], privacy: .public) \(ctx[2], privacy: .public) \(ctx[3], privacy: .public) \(ctx[4], privacy: .public) \(ctx[5], privacy: .public) \(ctx[6], privacy: .public) \(ctx[7], privacy: .public) \(ctx[8], privacy: .public) \(ctx[9], privacy: .public) \(ctx[10], privacy: .public) \(ctx[11], privacy: .public) \(ctx[12], privacy: .public) \(ctx[13], privacy: .public) \(ctx[14], privacy: .public) \(ctx[15], privacy: .public) \(ctx[16], privacy: .public) \(ctx[17], privacy: .public) \(ctx[18], privacy: .public) \(ctx[19], privacy: .public) \(ctx[20], privacy: .public) \(ctx[21], privacy: .public) \(ctx[22], privacy: .public) \(ctx[23], privacy: .public) id=\(id, privacy: .public)"
            )
        }
    }
}
