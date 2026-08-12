# ``OSLogHandler``

A sensitivity-aware log handler that uses the Darwin unified logging system (`os.Logger`).

## Overview

`OSLogHandler` integrates swift-log with the Darwin unified logging system. It gives native OSLog privacy
support to metadata values. Redaction denies by default. Only a value explicitly tagged `.public` stays
visible in collected logs. This handler redacts anything not proven safe as `<private>`.

## Output format

The handler emits the message, followed by the metadata split into a public segment and a private segment.

### Production logs

In a production environment (Console.app, a non-debug build), this handler redacts everything not explicitly
tagged `.public`:

```txt
Login successful action=password <private>
```

The `<private>` marker replaces the joined sensitive metadata. The message and any `.public` metadata stay
visible.

### Debug builds

When debugging (Xcode attached, or `log stream --level debug`), this handler shows private values for
troubleshooting:

```txt
Login successful action=password user.id=12345
```

## Usage

Create an `OSLogHandler` with your app's subsystem and category:

```swift
import Logging
import OSLogHandler
import SensitivityAttribute

let logger = Logger(label: "auth") { label in
    OSLogHandler(subsystem: "com.example.myapp", category: label)
}

let userId = "12345"
logger.info("Login successful", metadata: [
    "user.id": "\(userId, sensitivity: .sensitive)",
    "action": "\("password", sensitivity: .public)",
])
```

## Sensitivity behavior

- `.public` metadata: always visible, through OSLog's `privacy: .public`.
- `.sensitive`, untagged, and any future `Sensitivity` case: redacted as `<private>`.
- The message: emitted as `privacy: .public`. Keep sensitive data in metadata tagged `.sensitive`, not in the
  message text.

## Performance

Prefer a short, constant message and short metadata values. swift-log renders the message, and each metadata
value, into a `String` before this handler runs. A runtime-built `String` moves from inline storage to a
per-call heap allocation once it exceeds 15 UTF-8 bytes. A `String` literal of any length is free. This
handler derives its log level from the system's enablement, so a log at a disabled level drops before it even
builds the message. Not emitting the log at all is the strongest lever you have.

## Topics

### Creating a handler

- ``OSLogHandler/init(subsystem:category:)``
- ``OSLogHandler/init(label:)``
