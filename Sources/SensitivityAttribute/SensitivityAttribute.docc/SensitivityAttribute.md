# ``SensitivityAttribute``

Classify metadata values by sensitivity, so a handler can decide what to forward, redact, or drop.

## Overview

- ``Sensitivity`` is an attribute with two cases, `.public` and `.sensitive`, that conforms to `Logger.MetadataValueAttributes.Attribute`. 
Apply it within string interpolation (`"\(value, sensitivity: .public)"`) or the `.attributed` factory.
- ``RedactionLogHandler`` wraps another `LogHandler` to apply the redaction strategy you choose with `mode`.
  With the mode ``RedactionLogHandler/Mode/redacting``, it rewrites every metadata entry not tagged ``Sensitivity/public`` to `"<redacted>"` before it reaches the wrapped handler.
  When you use the mode ``RedactionLogHandler/Mode/passthrough``, it forwards every event unchanged.

## Usage

```swift
import Logging
import SensitivityAttribute

let redactingLogger = Logger(label: "app", factory: { label in
    RedactionLogHandler(
        mode: .redacting,
        wrapping: StreamLogHandler.standardOutput(label: label)
    )
})

redactingLogger.info("I am doing stuff", metadata: [
    "foo": "\("foo", sensitivity: .public)",
    "bar": "\("bar", sensitivity: .sensitive)",
])
```

Use ``RedactionLogHandler/Mode/passthrough`` in a development build to make the same handler graph forward
sensitive values unchanged.

## Topics

### Essentials

- ``Sensitivity``
- ``RedactionLogHandler``

### Best practices

- <doc:TestingRedaction>
