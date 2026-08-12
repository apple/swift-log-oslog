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
/// Sensitivity is a classification. It does not enforce anything on its own. A handler must opt in to act on
/// it. See ``RedactionLogHandler`` for a handler that redacts values based on this attribute.
///
/// `Sensitivity` is a non-frozen enum. Future versions of this package may add cases. Add a `default:` or
/// `@unknown default:` branch to every switch over `Sensitivity`:
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
/// If you need more classification dimensions, define your own `Logger.MetadataValueAttributes.Attribute`
/// type. Do not extend `Sensitivity`. `MetadataValueAttributes` stores an attribute as its `Int64` raw value.
/// An open-for-extension `Sensitivity` would let two cases collide on that raw value.
public enum Sensitivity: Int64, Sendable, Logger.MetadataValueAttributes.Attribute {
    /// The value holds sensitive data. Do not send it to a handler that excludes sensitive data.
    case sensitive = 1

    /// The value is safe to send to any handler.
    case `public` = 2
}
