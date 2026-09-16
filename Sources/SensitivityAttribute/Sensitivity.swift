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

/// Sensitivity classification for a metadata value.
///
/// Attach it with the `.attributed` factory:
///
/// ```swift
/// logger.info("Request", metadata: [
///     "user_id": .attributed(req.userId, attributes: [Sensitivity.sensitive]),
///     "method":  .attributed(req.method, attributes: [Sensitivity.public]),
/// ])
/// ```
///
/// Sensitivity is a classification for values and doesn't enforce anything on its own.
/// A handler must opt in to act on the classification.
/// For example, ``RedactionLogHandler`` provides a handler that redacts values based on this attribute.
///
/// `Sensitivity` is a non-frozen enum. Future versions of this package may add cases. The compiler requires a
/// `default:` or `@unknown default:` branch in every switch over `Sensitivity`:
///
/// ```swift
/// switch sensitivity {
/// case .sensitive: // ...
/// case .public:    // ...
/// @unknown default:
///     // Treat unknown values as the most restrictive option.
/// }
/// ```
///
/// Don't extend `Sensitivity`.
/// If you need more classification dimensions, define your own `Logger.MetadataValueAttributes.Attribute` type.
/// `MetadataValueAttributes` stores an attribute as its `Int64` raw value, so
/// an open-for-extension `Sensitivity` would let two cases collide on the raw value.
@nonexhaustive
public enum Sensitivity: Int64, Sendable, Logger.MetadataValueAttributes.Attribute {
    /// The value holds sensitive data. Do not send it to a handler that excludes sensitive data.
    case sensitive = 1

    /// The value is safe to send to any handler.
    case `public` = 2
}
