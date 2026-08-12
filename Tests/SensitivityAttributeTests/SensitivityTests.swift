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

import Logging
import Testing

@testable import SensitivityAttribute

@Suite
struct SensitivityTests {
    @Test
    func attributedFactoryProducesAttributedValue() {
        for attribute in [.public, .sensitive] as [Sensitivity] {
            let userId = "u-123"
            let value: Logger.MetadataValue = .attributed(userId, attributes: [attribute])
            #expect(value.description == userId)
            #expect(value.attributes[Sensitivity.self] == attribute)
        }
    }

    @Test
    func interpolationWithoutAttributesStaysPlain() {
        let value: Logger.MetadataValue = "\("hello")"
        #expect(value.attributes[Sensitivity.self] == nil)
    }

    @Test
    func interpolationWithSensitivityTagsValue() {
        for sensitivity in [.public, .sensitive] as [Sensitivity] {
            let userId = "u-123"
            let value: Logger.MetadataValue = "\(userId, sensitivity: sensitivity)"
            #expect(value.description == userId)
            #expect(value.attributes[Sensitivity.self] == sensitivity)
        }
    }

    @Test
    func interpolationWithSensitivityPreservesSurroundingLiteral() {
        let value: Logger.MetadataValue = "id=\("u-123", sensitivity: .sensitive)"
        #expect(value.description == "id=u-123")
        #expect(value.attributes[Sensitivity.self] == .sensitive)
    }

    @Test
    func laterSensitivitySegmentWins() {
        let value: Logger.MetadataValue =
            "\("first", sensitivity: .public)-\("second", sensitivity: .sensitive)"
        #expect(value.description == "first-second")
        #expect(value.attributes[Sensitivity.self] == .sensitive)
    }

    @Test
    func interpolationAcceptsNonStringCustomStringConvertible() {
        let value: Logger.MetadataValue = "\(42, sensitivity: .sensitive)"
        #expect(value.description == "42")
        #expect(value.attributes[Sensitivity.self] == .sensitive)
    }
}
