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

public import Logging

/// The fixed string written in place of a redacted metadata value.
private let redactionMarker: Logger.MetadataValue = "<redacted>"

/// Whether a ``RedactionLogHandler`` redacts sensitive metadata or forwards events unchanged.
public enum RedactionMode: Sendable {
    /// Replace every metadata value not tagged ``Sensitivity/public`` with the redaction marker.
    case redacting

    /// Forward every event unchanged.
    case passthrough
}

/// A log handler that wraps another to provide redaction.
///
/// The handler is controlled by it's ``Mode`` which either redacts sensitive metadata before forwarding or
/// forwards events unchanged.
/// You set the `Mode` of the handler when you construct it:
///
/// - ``Mode/redacting``: rewrites every metadata entry not tagged ``Sensitivity/public`` to the redaction
///   marker (`"<redacted>"`) before forwarding the values to the wrapped `Underlying` handler. 
///   Untagged entries count as treated as sensitive, which redacts them by default.
/// - ``Mode/passthrough``: forwards every event transparently.
///
/// ```swift
/// let console = StreamLogHandler.standardOutput(label: "console")
/// let handler = RedactionLogHandler(mode: .redacting, wrapping: console)
/// ```
///
/// ## Log level
///
/// `logLevel` forwards to `underlying.logLevel`.
/// Reading it reads the underlying handler's current level, and 
/// setting it sets underlying handler's level so the two never drift apart.
///
/// ## Redaction marker
///
/// A sensitive entry is replaced with the string `"<redacted>"`. Its attributes are dropped along with its
/// value, so a redacted entry cannot be re-classified or recovered downstream.
public struct RedactionLogHandler<Underlying: LogHandler>: LogHandler {
    /// Redaction mode.
    public let mode: RedactionMode

    /// Wrapped `LogHandler`.
    private var underlying: Underlying

    /// Wrapped `LogHandler`'s log level.
    public var logLevel: Logger.Level {
        get {
            underlying.logLevel
        }
        set {
            underlying.logLevel = newValue
        }
    }

    public var metadata: Logger.Metadata = [:] {
        didSet {
            self.redactedBaseMetadata = Self.redactedValues(self.metadata)
        }
    }

    /// The base ``metadata``, already redacted and cached. This avoids recomputing it on every emission. In
    /// `.redacting` mode, a log with no emission-time metadata forwards this directly. A log that carries
    /// emission-time metadata redacts only that metadata, then merges it on top. The base never gets
    /// re-redacted per log.
    private var redactedBaseMetadata: Logger.Metadata = [:]

    public var metadataProvider: Logger.MetadataProvider?

    /// Creates a redaction wrapper around another handler that you provide.
    ///
    /// - Parameters:
    ///   - mode: ``RedactionMode/redacting`` or ``RedactionMode/passthrough``. Fixed for the lifetime of the
    ///     wrapper.
    ///   - underlying: The handler that receives events after redaction.
    ///   - metadataProvider: An optional metadata provider. Its output merges into every event before
    ///     redaction.
    public init(
        mode: RedactionMode,
        wrapping underlying: Underlying,
        metadataProvider: Logger.MetadataProvider? = nil
    ) {
        self.mode = mode
        self.underlying = underlying
        self.metadataProvider = metadataProvider
    }

    public func log(event: LogEvent) {
        var routedEvent = event
        switch self.mode {
        case .redacting:
            routedEvent.metadata = self.redactedMetadata(forEmission: event.metadata)
        case .passthrough:
            routedEvent.metadata = self.mergedMetadata(forEmission: event.metadata)
        }
        self.underlying.log(event: routedEvent)
    }

    public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { self.metadata[key] }
        set { self.metadata[key] = newValue }
    }

    /// The metadata forwarded in `.redacting` mode. It combines the cached redacted base with the redacted
    /// emission-time metadata. Emission-time metadata wins on key conflicts.
    private func redactedMetadata(forEmission eventMetadata: Logger.Metadata?) -> Logger.Metadata? {
        guard let emission = self.emissionTimeMetadata(eventMetadata) else {
            // No emission-time metadata. Forward the cached redacted base directly.
            return self.redactedBaseMetadata.isEmpty ? nil : self.redactedBaseMetadata
        }
        let redactedEmission = Self.redactedValues(emission)
        if self.metadata.isEmpty {
            return redactedEmission
        }
        var combined = self.redactedBaseMetadata
        combined.merge(redactedEmission, uniquingKeysWith: { _, emitted in emitted })
        return combined
    }

    /// The metadata forwarded in `.passthrough` mode, unredacted. It combines the base with the emission-time
    /// metadata. Emission-time metadata wins on key conflicts.
    private func mergedMetadata(forEmission eventMetadata: Logger.Metadata?) -> Logger.Metadata? {
        guard let emission = self.emissionTimeMetadata(eventMetadata) else {
            // No emission-time metadata. Forward the base directly.
            return self.metadata.isEmpty ? nil : self.metadata
        }
        if self.metadata.isEmpty {
            return emission
        }
        var combined = self.metadata
        combined.merge(emission, uniquingKeysWith: { _, emitted in emitted })
        return combined
    }

    /// The emission-time metadata: the provider's output merged with the event's own metadata, where the event
    /// wins on conflicts. This is the metadata supplied at the log call.
    /// Returns `nil` when there is none. This excludes base metadata on purpose. The base is handled through
    /// the cached `redactedBaseMetadata`, or merged separately in passthrough mode.
    private func emissionTimeMetadata(_ eventMetadata: Logger.Metadata?) -> Logger.Metadata? {
        var emission = Logger.Metadata()
        if let provided = self.metadataProvider?.get(), !provided.isEmpty {
            emission = provided
        }
        if let eventMetadata, !eventMetadata.isEmpty {
            if emission.isEmpty {
                emission = eventMetadata
            } else {
                emission.merge(eventMetadata, uniquingKeysWith: { _, event in event })
            }
        }
        return emission.isEmpty ? nil : emission
    }

    /// Replaces every entry not tagged ``Sensitivity/public`` with the redaction marker. An untagged entry
    /// counts as sensitive.
    private static func redactedValues(_ metadata: Logger.Metadata) -> Logger.Metadata {
        metadata.mapValues { $0.attributes[Sensitivity.self] == .public ? $0 : redactionMarker }
    }
}
