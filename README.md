# Swift Log OSLog

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fapple%2Fswift-log-oslog%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/apple/swift-log-oslog)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fapple%2Fswift-log-oslog%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/apple/swift-log-oslog)

A [`swift-log`](https://github.com/apple/swift-log) backend implementation for Darwin `OSLog`.

## What it provides

### `SensitivityAttribute`

- `Sensitivity` — a two-case attribute (`.sensitive`, `.public`) that conforms to
  `Logger.MetadataValueAttributes.Attribute`.
- `RedactionLogHandler` — a `LogHandler` wrapper that rewrites metadata entries not tagged `.public` to
  `"<redacted>"` before forwarding.
> Check out [SLG-0004-metadata-value-attributes.md](https://github.com/apple/swift-log/blob/main/Sources/Logging/Docs.docc/Proposals/SLG-0004-metadata-value-attributes.md) to learn more about the metadata attributes in `swift-log`.

## Usage

Add dependency to the `Package.swift`:

```swift
.package(url: "https://github.com/apple/swift-log-oslog", .upToNextMinor(from: "0.1.0"))
```

```swift
.product(name: "SensitivityAttribute", package: "swift-log-oslog")
```

Then import `SensitivityAttribute` and start logging:

```swift
import Logging
import SensitivityAttribute

let redactingLogger = Logger(label: "my_app", factory: { label in
    RedactionLogHandler(
        wrapping: StreamLogHandler.standardOutput(label: label)
    )
})

redactingLogger.info("Hello, world", metadata: [
    "foo": "\("foo", sensitivity: .public)",
    "bar": "\("bar", sensitivity: .sensitive)"
])

// Outputs:
// 2026-10-01T09:41:00-0700 info my_app: bar=<redacted> foo=foo [my_app] Hello, world
```

In a development build, install `StreamLogHandler.standardOutput(label:)` directly, without wrapping it in a
`RedactionLogHandler`, to forward sensitive values unchanged.
