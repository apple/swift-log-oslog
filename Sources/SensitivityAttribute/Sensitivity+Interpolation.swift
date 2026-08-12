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

extension Logger.MetadataValue.StringInterpolation {
    /// Interpolates a value and tags it with a ``Sensitivity`` classification.
    ///
    /// Use this to attach a ``Sensitivity`` to one interpolation segment, without writing out the attributes
    /// closure:
    ///
    /// ```swift
    /// logger.info("Request", metadata: [
    ///     "user_id": "\(req.userId, sensitivity: .sensitive)",
    ///     "method":  "\(req.method, sensitivity: .public)",
    /// ])
    /// ```
    ///
    /// This appends the value's `description` to the interpolated string. It sets the segment's attributes so
    /// `value.attributes[Sensitivity.self]` returns `sensitivity`. If more than one segment sets a
    /// `Sensitivity`, the last one wins. This matches `Logger.MetadataValueAttributes` merge behavior.
    ///
    /// - Parameters:
    ///   - value: The value to interpolate. Its `description` is appended to the result.
    ///   - sensitivity: The classification to attach to this segment.
    public mutating func appendInterpolation<T: CustomStringConvertible & Sendable>(
        _ value: T,
        sensitivity: Sensitivity
    ) {
        self.appendInterpolation(value, attributes: { $0[Sensitivity.self] = sensitivity })
    }
}
