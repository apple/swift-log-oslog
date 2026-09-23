# ``SensitivityAttribute``

Classify metadata values by sensitivity, so a handler can decide what to forward, redact, or drop.

## Overview

- ``Sensitivity`` is an attribute with two cases, `.public` and `.sensitive`, that conforms to `Logger.MetadataValueAttributes.Attribute`. 
Apply it within string interpolation (`"\(value, sensitivity: .public)"`) or the `.attributed` factory.
- ``RedactionLogHandler`` wraps another `LogHandler` to redact sensitive metadata.
  It rewrites every metadata entry not tagged ``Sensitivity/public`` to `"<redacted>"` before it reaches the
  wrapped handler.

## Usage

```swift
import Logging
import SensitivityAttribute

let redactingLogger = Logger(label: "app", factory: { label in
    RedactionLogHandler(
        wrapping: StreamLogHandler.standardOutput(label: label)
    )
})

redactingLogger.info("I am doing stuff", metadata: [
    "foo": "\("foo", sensitivity: .public)",
    "bar": "\("bar", sensitivity: .sensitive)",
])
```

In a development build, install the underlying handler directly, without wrapping it in a
``RedactionLogHandler``, to forward sensitive values unchanged.

## Topics

### Essentials

- ``Sensitivity``
- ``RedactionLogHandler``

### Best practices

- <doc:TestingRedaction>
