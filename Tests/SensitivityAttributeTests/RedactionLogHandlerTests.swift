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

import InMemoryLogging
import Logging
import Testing

@testable import SensitivityAttribute

@Suite
struct RedactionLogHandlerTests {
    @Test
    func redactsSensitiveAndUntaggedButKeepsPublic() throws {
        let sink = RecordingLogHandler()
        let logger = Logger(label: "test") { _ in
            RedactionLogHandler(wrapping: sink)
        }

        logger.info(
            "request",
            metadata: [
                "method": .attributed("GET", attributes: [Sensitivity.public]),
                "user_id": .attributed("u-123", attributes: [Sensitivity.sensitive]),
                "client_ip": "203.0.113.5",  // untagged: treated as sensitive
            ]
        )

        let event = try #require(sink.events.first)
        #expect(event.metadata?["method"]?.description == "GET")
        #expect(event.metadata?["user_id"]?.description == "<redacted>")
        #expect(event.metadata?["client_ip"]?.description == "<redacted>")
        // A redacted value drops its attributes along with its original content.
        #expect(event.metadata?["user_id"]?.attributes[Sensitivity.self] == nil)
    }

    @Test
    func baseMetadataIsMergedAndRedacted() throws {
        let sink = RecordingLogHandler()
        var logger = Logger(label: "test") { _ in
            RedactionLogHandler(wrapping: sink)
        }
        logger[metadataKey: "session"] = .attributed("s-1", attributes: [Sensitivity.sensitive])
        logger[metadataKey: "build"] = .attributed("release", attributes: [Sensitivity.public])

        logger.info("boot")

        let event = try #require(sink.events.first)
        #expect(event.metadata?["session"]?.description == "<redacted>")
        #expect(event.metadata?["build"]?.description == "release")
    }

    @Test
    func emptyMetadataForwardsAsNil() throws {
        let sink = RecordingLogHandler()
        let logger = Logger(label: "test") { _ in
            RedactionLogHandler(wrapping: sink)
        }

        logger.info("ping")

        let event = try #require(sink.events.first)
        #expect(event.metadata == nil)
    }

    @Test
    func logLevelReadsThroughToUnderlyingAtConstruction() {
        let sink = RecordingLogHandler(logLevel: .warning)
        let logger = Logger(label: "test") { _ in
            RedactionLogHandler(wrapping: sink)
        }
        #expect(logger.logLevel == .warning)
    }

    @Test
    func settingWrapperLogLevelWritesThroughToUnderlying() {
        var logger = Logger(label: "test") { _ in
            RedactionLogHandler(wrapping: InMemoryLogHandler())
        }
        logger.logLevel = .critical
        // The wrapper holds its own copy of a struct Underlying, so only the wrapper's own getter can show
        // the write-through. This confirms the setter reached `underlying`, not a separate stored property
        // that happens to read back the same value.
        #expect(logger.logLevel == .critical)
    }

    @Test
    func loweringWrapperLogLevelUnblocksMessagesThroughAComposedUnderlying() throws {
        // MultiplexLogHandler re-filters internally. `log(event:)` forwards only to a constituent handler
        // whose own `logLevel` is at least as permissive as the event. If RedactionLogHandler's `logLevel`
        // were a detached snapshot instead of a live passthrough, lowering it after construction would open
        // Logger's outer gate but not the MultiplexLogHandler's own gate. The message would still drop
        // silently, one layer in.
        let sink = RecordingLogHandler(logLevel: .info)
        var logger = Logger(label: "test") { _ in
            RedactionLogHandler(wrapping: MultiplexLogHandler([sink]))
        }

        logger.logLevel = .trace
        logger.trace("should reach the sink")

        #expect(sink.events.count == 1)
    }

    @Test
    func baseAndEventMetadataAreCombined() throws {
        let sink = RecordingLogHandler()
        var logger = Logger(label: "test") { _ in
            RedactionLogHandler(wrapping: sink)
        }
        logger[metadataKey: "build"] = .attributed("release", attributes: [Sensitivity.public])
        logger[metadataKey: "session"] = .attributed("s-1", attributes: [Sensitivity.sensitive])

        logger.info(
            "request",
            metadata: [
                "method": .attributed("GET", attributes: [Sensitivity.public]),
                "user_id": .attributed("u-123", attributes: [Sensitivity.sensitive]),
            ]
        )

        let event = try #require(sink.events.first)
        #expect(event.metadata?["build"]?.description == "release")
        #expect(event.metadata?["session"]?.description == "<redacted>")
        #expect(event.metadata?["method"]?.description == "GET")
        #expect(event.metadata?["user_id"]?.description == "<redacted>")
    }

    @Test
    func eventMetadataOverridesBaseOnKeyCollision() throws {
        let sink = RecordingLogHandler()
        var logger = Logger(label: "test") { _ in
            RedactionLogHandler(wrapping: sink)
        }
        logger[metadataKey: "user_id"] = .attributed("base", attributes: [Sensitivity.public])

        logger.info(
            "request",
            metadata: ["user_id": .attributed("event", attributes: [Sensitivity.public])]
        )

        let event = try #require(sink.events.first)
        #expect(event.metadata?["user_id"]?.description == "event")
    }

    @Test
    func metadataProviderOutputIsMergedAndRedacted() throws {
        let sink = RecordingLogHandler()
        let provider = Logger.MetadataProvider {
            [
                "trace_id": .attributed("t-1", attributes: [Sensitivity.public]),
                "auth_token": .attributed("secret", attributes: [Sensitivity.sensitive]),
            ]
        }
        let logger = Logger(label: "test") { _ in
            RedactionLogHandler(wrapping: sink, metadataProvider: provider)
        }

        logger.info("request")

        let event = try #require(sink.events.first)
        #expect(event.metadata?["trace_id"]?.description == "t-1")
        #expect(event.metadata?["auth_token"]?.description == "<redacted>")
    }

    @Test
    func eventMetadataOverridesMetadataProviderOnKeyCollision() throws {
        let sink = RecordingLogHandler()
        let provider = Logger.MetadataProvider {
            ["trace_id": .attributed("from-provider", attributes: [Sensitivity.public])]
        }
        let logger = Logger(label: "test") { _ in
            RedactionLogHandler(wrapping: sink, metadataProvider: provider)
        }

        logger.info(
            "request",
            metadata: ["trace_id": .attributed("from-event", attributes: [Sensitivity.public])]
        )

        let event = try #require(sink.events.first)
        #expect(event.metadata?["trace_id"]?.description == "from-event")
    }

    @Test
    func metadataProviderOverridesBaseOnKeyCollision() throws {
        let sink = RecordingLogHandler()
        let provider = Logger.MetadataProvider {
            ["request_id": .attributed("from-provider", attributes: [Sensitivity.public])]
        }
        var logger = Logger(label: "test") { _ in
            RedactionLogHandler(wrapping: sink, metadataProvider: provider)
        }
        logger[metadataKey: "request_id"] = .attributed("from-base", attributes: [Sensitivity.public])

        logger.info("request")

        let event = try #require(sink.events.first)
        #expect(event.metadata?["request_id"]?.description == "from-provider")
    }

    @Test
    func emptyMetadataProviderOutputDoesNotInjectKeys() throws {
        let sink = RecordingLogHandler()
        let provider = Logger.MetadataProvider { [:] }
        let logger = Logger(label: "test") { _ in
            RedactionLogHandler(wrapping: sink, metadataProvider: provider)
        }

        logger.info(
            "request",
            metadata: ["method": .attributed("GET", attributes: [Sensitivity.public])]
        )

        let event = try #require(sink.events.first)
        #expect(event.metadata?.count == 1)
        #expect(event.metadata?["method"]?.description == "GET")
    }

    @Test
    func emptyEventMetadataDictionaryReturnsNilWhenProviderAlsoEmpty() throws {
        let sink = RecordingLogHandler()
        let provider = Logger.MetadataProvider { [:] }
        let logger = Logger(label: "test") { _ in
            RedactionLogHandler(wrapping: sink, metadataProvider: provider)
        }

        logger.info("ping", metadata: [:])

        let event = try #require(sink.events.first)
        #expect(event.metadata == nil)
    }

    @Test
    func metadataKeySubscriptGetReturnsSetValue() {
        let sink = RecordingLogHandler()
        var logger = Logger(label: "test") { _ in
            RedactionLogHandler(wrapping: sink)
        }
        logger[metadataKey: "k"] = .attributed("v", attributes: [Sensitivity.public])
        #expect(logger[metadataKey: "k"]?.description == "v")
        #expect(logger[metadataKey: "missing"] == nil)
    }
}
