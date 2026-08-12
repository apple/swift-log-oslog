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

#if canImport(os)
public import Logging
import SensitivityAttribute
import os

/// A redaction-aware log handler that uses the Darwin unified logging system (`os.Logger`).
///
/// This handler uses OSLog's native privacy support. It redacts a metadata value unless the value is tagged
/// ``Sensitivity/public``. Anything not proven safe stays out of collected logs.
///
/// ## Features
///
/// - Native privacy support: uses OSLog's `privacy: .private` and `privacy: .public` annotations.
/// - System integration: logs appear in Console.app and with the `log` command.
/// - Performance: zero cost when logging is disabled at the system level.
/// - Subsystem organization: groups logs by subsystem and category for filtering.
///
/// ## Usage
///
/// ```swift
/// let handler = OSLogHandler(subsystem: "com.example.myapp", category: "network")
/// let logger = Logger(label: "network") { _ in handler }
///
/// let userId = "12345"
/// logger.info("User logged in", metadata: [
///     "user.id": "\(userId, sensitivity: .sensitive)",
///     "action": "\(\"login\", sensitivity: .public)",
/// ])
/// ```
///
/// ## Redaction behavior
///
/// Redaction denies by default, matching `RedactionLogHandler`:
///
/// - ``Sensitivity/public`` metadata maps to OSLog `privacy: .public`. It stays visible.
/// - Everything else maps to OSLog `privacy: .private`, shown as `<private>` in collected logs. This
///   includes ``Sensitivity/sensitive``, untagged values, and any future `Sensitivity` case.
///
/// The log message itself is emitted as `privacy: .public`. OSLog redacts a dynamic string by default, which
/// would render every message as `<private>`. The message is a developer-authored line, so this handler
/// treats it like every other swift-log handler does. Keep sensitive data in metadata tagged
/// ``Sensitivity/sensitive``, not in the message.
@available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
public struct OSLogHandler: LogHandler {
    @usableFromInline
    internal var osLogger: os.Logger

    /// A parallel `OSLog` handle. Used only to query the unified logging system's current per-type enablement
    /// with `isEnabled(type:)` when deriving ``logLevel``. `os.Logger` does not expose enablement, so this
    /// handler keeps both. Both refer to the same subsystem and category.
    internal let osLog: OSLog

    /// The base (logger) metadata, kept pre-split by ``Sensitivity``, so it never needs re-partitioning per
    /// log. ``Sensitivity/public`` entries live here. Everything else lives in ``privateBaseMetadata``. The
    /// two halves have disjoint keys.
    @usableFromInline package var publicBaseMetadata: Logging.Logger.Metadata = [:]
    @usableFromInline package var privateBaseMetadata: Logging.Logger.Metadata = [:]

    /// Cached `key=value` flattenings of the two base halves. These recompute only when the base metadata
    /// changes. A log with no emission-time metadata reuses them directly. A log with emission-time metadata
    /// partitions only that metadata and appends it. The base string is never re-flattened on the hot path.
    @usableFromInline package var publicBaseString: String = ""
    @usableFromInline package var privateBaseString: String = ""

    /// The base metadata as a single dictionary. It is stored split by sensitivity (see ``publicBaseMetadata``).
    /// This getter reunites the two halves, since their keys are disjoint. The setter re-splits and
    /// re-flattens them.
    public var metadata: Logging.Logger.Metadata {
        get {
            if self.privateBaseMetadata.isEmpty { return self.publicBaseMetadata }
            if self.publicBaseMetadata.isEmpty { return self.privateBaseMetadata }
            return self.publicBaseMetadata.merging(self.privateBaseMetadata) { keep, _ in keep }
        }
        set {
            self.publicBaseMetadata = [:]
            self.privateBaseMetadata = [:]
            for (key, value) in newValue {
                if value.attributes[Sensitivity.self] == .public {
                    self.publicBaseMetadata[key] = value
                } else {
                    self.privateBaseMetadata[key] = value
                }
            }
            self.publicBaseString = Self.flatten(self.publicBaseMetadata)
            self.privateBaseString = Self.flatten(self.privateBaseMetadata)
        }
    }

    public var metadataProvider: Logging.Logger.MetadataProvider?

    /// An explicit log-level override. When `nil` (the default), ``logLevel`` is derived from the
    /// system's current enablement.
    internal var explicitLogLevel: Logging.Logger.Level?

    /// The effective log level.
    ///
    /// With no explicit override, this reflects the unified logging system's current enablement for this
    /// subsystem and category. swift-log compares it against each message's level before it builds the
    /// message. A level the system has disabled drops by a cheap comparison, instead of building and
    /// forwarding a log line the system would discard anyway. This is the difference between a full ~250 ns
    /// log call and a ~5 ns gate on the hot path.
    ///
    /// Assigning a value installs an explicit override that wins over system enablement. This preserves the
    /// value-semantics behavior a `LogHandler` must have. Unified logging enablement is a system-wide
    /// setting, so the derived (non-overridden) value can legitimately differ across processes and change at
    /// runtime. The `LogHandler` contract permits such global overrides.
    public var logLevel: Logging.Logger.Level {
        get { self.explicitLogLevel ?? Self.systemLogLevel(self.osLog) }
        set { self.explicitLogLevel = newValue }
    }

    /// Creates an OSLog handler with the specified subsystem and category.
    ///
    /// - Parameters:
    ///   - subsystem: The identifier for the subsystem emitting the logs, typically a reverse-DNS string
    ///     such as `"com.example.myapp"`.
    ///   - category: The category to group these logs under, for filtering in Console.app or with the `log`
    ///     command.
    public init(subsystem: String, category: String) {
        self.osLogger = os.Logger(subsystem: subsystem, category: category)
        self.osLog = OSLog(subsystem: subsystem, category: category)
    }

    /// Creates an OSLog handler from a swift-log label.
    ///
    /// The `label` is used as the `os.Logger` subsystem with a `"default"` category, so the handler can be used
    /// directly as a `LoggingSystem.bootstrap` factory. Use ``init(subsystem:category:)`` for finer control.
    ///
    /// - Parameter label: The swift-log label, used as the `os.Logger` subsystem.
    public init(label: String) {
        self.init(subsystem: label, category: "default")
    }

    @inlinable
    public func log(event: LogEvent) {
        let level = Self.osLogType(for: event.level)

        let publicString: String
        let privateString: String
        if let emission = self.emissionTimeMetadata(for: event) {
            if self.emissionOverlapsBase(emission) {
                // Rare: an emission-time key also names a base entry. Merge so emission-time wins (base
                // loses to emission), then partition the whole. This keeps override precedence correct.
                var merged = self.publicBaseMetadata
                merged.merge(self.privateBaseMetadata) { keep, _ in keep }
                merged.merge(emission) { _, emitted in emitted }
                (publicString, privateString) = Self.partition(merged)
            } else {
                // Common: keys are disjoint. Partition only the small emission-time metadata and append it
                // to the cached base partition. The base string is never re-flattened.
                let (emittedPublic, emittedPrivate) = Self.partition(emission)
                publicString = Self.appending(emittedPublic, to: self.publicBaseString)
                privateString = Self.appending(emittedPrivate, to: self.privateBaseString)
            }
        } else {
            // No emission-time metadata: the base partition, already cached, is the whole output.
            (publicString, privateString) = (self.publicBaseString, self.privateBaseString)
        }

        switch (publicString.isEmpty, privateString.isEmpty) {
        case (false, false):
            self.osLogger.log(
                level: level,
                "\(event.message.description, privacy: .public) \(publicString, privacy: .public) \(privateString, privacy: .private)"
            )
        case (false, true):
            self.osLogger.log(
                level: level,
                "\(event.message.description, privacy: .public) \(publicString, privacy: .public)"
            )
        case (true, false):
            self.osLogger.log(
                level: level,
                "\(event.message.description, privacy: .public) \(privateString, privacy: .private)"
            )
        case (true, true):
            self.osLogger.log(level: level, "\(event.message.description, privacy: .public)")
        }
    }

    public subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
        get { self.publicBaseMetadata[key] ?? self.privateBaseMetadata[key] }
        set {
            self.publicBaseMetadata[key] = nil
            self.privateBaseMetadata[key] = nil
            if let newValue {
                if newValue.attributes[Sensitivity.self] == .public {
                    self.publicBaseMetadata[key] = newValue
                } else {
                    self.privateBaseMetadata[key] = newValue
                }
            }
            self.publicBaseString = Self.flatten(self.publicBaseMetadata)
            self.privateBaseString = Self.flatten(self.privateBaseMetadata)
        }
    }

    // MARK: - Pure helpers (package access for testing)

    /// The emission-time metadata: the metadata provider's output merged with the event's own metadata (the
    /// event wins on conflicts), plus injected error fields. This is the metadata supplied at the log call,
    /// separate from the base metadata configured on the handler. Returns `nil` when there is none.
    @usableFromInline
    package func emissionTimeMetadata(for event: LogEvent) -> Logging.Logger.Metadata? {
        var metadata = Logging.Logger.Metadata()
        if let provided = self.metadataProvider?.get(), !provided.isEmpty {
            metadata = provided
        }
        if let eventMetadata = event.metadata, !eventMetadata.isEmpty {
            if metadata.isEmpty {
                metadata = eventMetadata
            } else {
                metadata.merge(eventMetadata, uniquingKeysWith: { _, emitted in emitted })
            }
        }
        if let error = event.error {
            if metadata["error.message"] == nil {
                metadata["error.message"] = "\(error)"
            }
            if metadata["error.type"] == nil {
                metadata["error.type"] = "\(String(reflecting: type(of: error)))"
            }
        }
        return metadata.isEmpty ? nil : metadata
    }

    /// Whether any emission-time key also names a base entry. This is the one case where appending would
    /// duplicate a key, so the caller falls back to a full merge (base loses to emission) instead of
    /// appending.
    @usableFromInline
    package func emissionOverlapsBase(_ emission: Logging.Logger.Metadata) -> Bool {
        for key in emission.keys where self.publicBaseMetadata[key] != nil || self.privateBaseMetadata[key] != nil {
            return true
        }
        return false
    }

    /// Flattens metadata into a sorted `key=value` string. Does not split by sensitivity. Used for an
    /// already-split base half, whose entries are all on the same side.
    package static func flatten(_ metadata: Logging.Logger.Metadata) -> String {
        var result = ""
        result.reserveCapacity(metadata.keys.reduce(0) { $0 + $1.utf8.count + 2 } + metadata.count)
        for (key, value) in metadata.sorted(by: { $0.key < $1.key }) {
            if !result.isEmpty { result.append(" ") }
            result.append(key)
            result.append("=")
            result.append(value.description)
        }
        return result
    }

    /// Appends `field` to `base` separated by a space, avoiding a copy when either side is empty.
    @usableFromInline
    package static func appending(_ field: String, to base: String) -> String {
        if field.isEmpty { return base }
        if base.isEmpty { return field }
        return base + " " + field
    }

    /// Splits metadata into a public and a private `key=value` string in one sorted pass.
    ///
    /// Denies by default: only a value explicitly tagged ``Sensitivity/public`` goes to the public string.
    /// Everything else goes to the private string. Entries sort by key for deterministic output. The two
    /// strings build directly, so this skips the intermediate arrays and per-entry interpolation a
    /// multi-pass filter would need.
    @usableFromInline
    package static func partition(
        _ metadata: Logging.Logger.Metadata
    ) -> (publicString: String, privateString: String) {
        var publicString = ""
        var privateString = ""
        for (key, value) in metadata.sorted(by: { $0.key < $1.key }) {
            let isPublic = value.attributes[Sensitivity.self] == .public
            if isPublic {
                if !publicString.isEmpty { publicString.append(" ") }
                publicString.append(key)
                publicString.append("=")
                publicString.append(value.description)
            } else {
                if !privateString.isEmpty { privateString.append(" ") }
                privateString.append(key)
                privateString.append("=")
                privateString.append(value.description)
            }
        }
        return (publicString, privateString)
    }

    /// Maps a swift-log level to the closest `OSLogType`.
    ///
    /// OSLog has five levels for swift-log's seven, so two pairs collapse: `trace` and `debug` both map to
    /// `.debug`, and `notice` and `warning` both map to `.default`. `.error` is reserved for swift-log
    /// `.error`, so Console's error filter stays meaningful. `.default` still persists to disk, so a warning
    /// is not lost.
    @usableFromInline
    package static func osLogType(for level: Logging.Logger.Level) -> OSLogType {
        switch level {
        case .trace, .debug: return .debug
        case .info: return .info
        case .notice, .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }

    /// Derives a swift-log threshold from the unified logging system's current per-type enablement.
    ///
    /// Enablement is monotonic in practice. Enabling `.debug` implies `.info`, and so on. So a single
    /// threshold faithfully approximates it. This probes from most to least verbose, so the common case
    /// (fine-grained levels disabled) short-circuits after one or two checks. The `isEnabled` guard in
    /// ``log(event:)`` still catches any non-monotonic gap per call.
    package static func systemLogLevel(_ osLog: OSLog) -> Logging.Logger.Level {
        if osLog.isEnabled(type: .debug) { return .trace }
        if osLog.isEnabled(type: .info) { return .info }
        if osLog.isEnabled(type: .default) { return .notice }
        if osLog.isEnabled(type: .error) { return .error }
        return .critical
    }
}

#endif
