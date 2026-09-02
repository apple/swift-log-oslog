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

/// Pure `os.Logger` baseline: a native argument, no swift-log. The fully optimized os_log path everything
/// else is measured against.
func pureBenchmarks(configuration: Benchmark.Configuration) {
    let osLogger = os.Logger(subsystem: "com.example.applelogbench", category: "pure")
    Benchmark("pure_oslog", configuration: configuration) { _ in
        osLogger.info("req \(42, privacy: .public)")
    }

    // The same os.Logger, but logging a runtime String, as a dynamic `%{public}s` argument, instead of a
    // native scalar. This isolates the one allocation the bridge shows on a no-metadata log: os_log allocates
    // to serialize a dynamic string argument, while `pure_oslog`'s folded static format and native integer
    // allocate nothing. That allocation is os_log's doing, not swift-log's: the bridge just hands os_log the
    // message as a runtime `String`. Expect this to match the bridge's allocation count, not `pure_oslog`'s.
    let dynamicMessage = CommandLine.arguments.first ?? "req"
    Benchmark("pure_oslog_dynamic_string", configuration: configuration) { _ in
        osLogger.log(level: .info, "\(dynamicMessage, privacy: .public)")
    }

    // The pure-os_log equivalent of `bridge_scope_large_base_multiple_emissions`. `os.Logger` has no scoped
    // metadata, no `mergingMetadata`, so this re-specifies the 24 context fields the bridge attaches once, as
    // 24 dynamic `%{public}s` arguments, on every one of the 10 emissions. os_log may truncate the rendered
    // line at runtime, but what this measures is the packing cost of the 24 arguments.
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
