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

/// Mirrors the example in `SensitivityAttribute.docc/TestingRedaction.md`. Keep the two in sync.
@Suite
struct TestingRedactionDocTests {
    private struct LoginService {
        func login(userID: String, logger: Logger) {
            logger.info(
                "Login successful",
                metadata: [
                    "user.id": "\(userID, sensitivity: .sensitive)",
                    "action": "\("password", sensitivity: .public)",
                ]
            )
        }

        func login(userID: String) {
            self.login(userID: userID, logger: Logger.current)
        }
    }

    @Test
    func redactsUserID() {
        let explicitSink = InMemoryLogHandler()
        let explicitLogger = Logger(
            label: "test",
            factory: { _ in RedactionLogHandler(mode: .redacting, wrapping: explicitSink) }
        )
        LoginService().login(userID: "u-123", logger: explicitLogger)
        #expect(explicitSink.entries[0].metadata["user.id"]?.description == "<redacted>")
        #expect(explicitSink.entries[0].metadata["action"]?.description == "password")

        let taskLocalSink = InMemoryLogHandler()
        withLogger(handler: RedactionLogHandler(mode: .redacting, wrapping: taskLocalSink)) { _ in
            LoginService().login(userID: "u-123")
        }
        #expect(taskLocalSink.entries[0].metadata["user.id"]?.description == "<redacted>")
        #expect(taskLocalSink.entries[0].metadata["action"]?.description == "password")
    }
}
