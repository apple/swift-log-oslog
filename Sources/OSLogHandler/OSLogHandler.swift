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

/// A log handler that uses the Darwin unified logging system (`os.Logger`) and its native privacy support.
///
/// Marks a metadata value private unless it's tagged ``Sensitivity/public``.
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
/// - ``Sensitivity/public`` maps to OSLog `privacy: .public` and stays visible.
/// - Everything else maps to `privacy: .private` and shows as `<private>`. This includes
///   ``Sensitivity/sensitive``, untagged values, and future `Sensitivity` cases.
/// - The message itself is always `privacy: .public`. OSLog would otherwise redact every dynamic message.
///   Keep sensitive data in metadata, not the message.
@available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
public struct OSLogHandler: LogHandler {
    @usableFromInline
    internal var osLogger: os.Logger

    /// A parallel `OSLog` handle, used only to query enablement for ``logLevel``. `os.Logger` itself cannot
    /// report which levels the system has enabled.
    internal let osLog: OSLog

    /// Base metadata, split by ``Sensitivity`` ahead of time. This avoids repartitioning on every log.
    /// ``Sensitivity/public`` entries are stored in ``publicBaseMetadata``. Everything else is in
    /// ``privateBaseMetadata``.
    @usableFromInline package var publicBaseMetadata: Logging.Logger.Metadata = [:]
    @usableFromInline package var privateBaseMetadata: Logging.Logger.Metadata = [:]

    /// Caches a `key=value` flattening of each base half. Recomputes only when the base metadata changes.
    @usableFromInline package var publicBaseString: String = ""
    @usableFromInline package var privateBaseString: String = ""

    /// Base metadata as one dictionary. Reunites the two halves. The setter re-splits and re-flattens them.
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

    /// Explicit log-level override. 
    ///
    /// `nil` means derive the level from the system's per-type enablement. See
    /// ``systemLogLevel(_:)``.
    internal var explicitLogLevel: Logging.Logger.Level?

    /// The effective log level.
    ///
    /// With no override, this derives from the system's current per-type enablement. See
    /// ``systemLogLevel(_:)``. A disabled level drops via a cheap comparison instead of building the log
    /// line. Assigning a value installs an explicit override that wins from then on. This preserves
    /// `LogHandler`'s value-semantics contract. System enablement is process-wide, so the derived value can
    /// legitimately differ across processes and change at runtime.
    public var logLevel: Logging.Logger.Level {
        get { self.explicitLogLevel ?? Self.systemLogLevel(self.osLog) }
        set { self.explicitLogLevel = newValue }
    }

    /// Creates an OSLog handler with the specified subsystem and category.
    ///
    /// - Parameters:
    ///   - subsystem: Reverse-DNS identifier for the subsystem, e.g. `"com.example.myapp"`.
    ///   - category: Category for filtering in Console.app or with `log`.
    public init(subsystem: String, category: String) {
        self.osLogger = os.Logger(subsystem: subsystem, category: category)
        self.osLog = OSLog(subsystem: subsystem, category: category)
    }

    /// Creates an OSLog handler from a swift-log label.
    ///
    /// Uses `label` as the subsystem and `"default"` as the category. Use ``init(subsystem:category:)`` for
    /// finer control.
    ///
    /// - Parameter label: Becomes the `os.Logger` subsystem.
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
                // Rare: emission-time key collides with a base key. Merge the two, where emission-time
                // metadata wins on conflicts, then partition the result.
                var merged = self.publicBaseMetadata
                merged.merge(self.privateBaseMetadata) { keep, _ in keep }
                merged.merge(emission) { _, emitted in emitted }
                (publicString, privateString) = Self.partition(merged)
            } else {
                // Common: no collision. Partition just the emission-time metadata and append to the cached
                // base.
                let (emittedPublic, emittedPrivate) = Self.partition(emission)
                publicString = Self.appending(emittedPublic, to: self.publicBaseString)
                privateString = Self.appending(emittedPrivate, to: self.privateBaseString)
            }
        } else {
            // No emission-time metadata: use the cached base partition directly.
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

    /// Emission-time metadata for one log call. It merges the metadata provider's output with the event's
    /// own metadata, where the event wins on conflicts, plus injected error fields. Returns `nil` when
    /// empty. Excludes base metadata.
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

    /// Whether an emission-time key also names a base entry. Appending would duplicate that key in this
    /// case.
    @usableFromInline
    package func emissionOverlapsBase(_ emission: Logging.Logger.Metadata) -> Bool {
        for key in emission.keys where self.publicBaseMetadata[key] != nil || self.privateBaseMetadata[key] != nil {
            return true
        }
        return false
    }

    /// Flattens already-split metadata into a sorted `key=value` string.
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

    /// Appends `field` to `base`, separated by a space. Skips the copy when either side is empty.
    @usableFromInline
    package static func appending(_ field: String, to base: String) -> String {
        if field.isEmpty { return base }
        if base.isEmpty { return field }
        return base + " " + field
    }

    /// Splits metadata into sorted public/private `key=value` strings in one pass. Denies by default: only
    /// ``Sensitivity/public`` goes to the public string.
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

    /// Maps a swift-log level to the closest `OSLogType`. OSLog has five levels for swift-log's seven:
    /// `trace`/`debug` collapse to `.debug`, `notice`/`warning` collapse to `.default`.
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

    /// Derives a swift-log threshold from the system's per-type enablement. Assumes enablement is monotonic
    /// (`.debug` implies `.info`, etc.) and probes from most to least verbose.
    package static func systemLogLevel(_ osLog: OSLog) -> Logging.Logger.Level {
        if osLog.isEnabled(type: .debug) { return .trace }
        if osLog.isEnabled(type: .info) { return .info }
        if osLog.isEnabled(type: .default) { return .notice }
        if osLog.isEnabled(type: .error) { return .error }
        return .critical
    }
}

#endif
