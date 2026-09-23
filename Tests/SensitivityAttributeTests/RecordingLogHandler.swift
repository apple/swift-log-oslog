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

import Foundation
import Logging

/// Minimal thread-safe in-memory `LogHandler` shared across the test suites.
///
/// `@unchecked Sendable`: every stored property is guarded by `lock`, the class is `final`, and no escaping
/// closure exposes the inner state.
final class RecordingLogHandler: LogHandler, @unchecked Sendable {
    private let lock = NSLock()
    private var _events: [LogEvent] = []
    private var _metadata: Logger.Metadata = [:]
    private var _metadataProvider: Logger.MetadataProvider?
    private var _logLevel: Logger.Level

    init(logLevel: Logger.Level = .trace) {
        self._logLevel = logLevel
    }

    var events: [LogEvent] {
        self.lock.withLock { self._events }
    }

    var metadata: Logger.Metadata {
        get { self.lock.withLock { self._metadata } }
        set { self.lock.withLock { self._metadata = newValue } }
    }

    var metadataProvider: Logger.MetadataProvider? {
        get { self.lock.withLock { self._metadataProvider } }
        set { self.lock.withLock { self._metadataProvider = newValue } }
    }

    var logLevel: Logger.Level {
        get { self.lock.withLock { self._logLevel } }
        set { self.lock.withLock { self._logLevel = newValue } }
    }

    func log(event: LogEvent) {
        self.lock.withLock { self._events.append(event) }
    }

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { self.lock.withLock { self._metadata[key] } }
        set { self.lock.withLock { self._metadata[key] = newValue } }
    }
}
