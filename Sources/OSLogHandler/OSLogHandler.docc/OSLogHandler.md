# ``OSLogHandler``

A sensitivity-aware log handler for the Darwin unified logging system.

## Overview

The OSLogHandler is a sensitivity-aware log handler for the Darwin unified logging system that maps
`Sensitivity` values to the OSLog privacy model.

## Usage

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

Production logs (Console.app, non-debug builds):

```txt
Login successful action=password <private>
```

Debug builds (Xcode attached, or `log stream --level debug`):

```txt
Login successful action=password user.id=12345
```

## Sensitivity behavior

- `.public` metadata: always visible.
- Everything else, including `.sensitive`, untagged values, and future cases: redacted as `<private>`.
- The message itself is always `privacy: .public`. Keep sensitive data in metadata, not the message.

## Performance

Prefer short, constant messages and short metadata values. A runtime-built `String` allocates once it
exceeds 15 UTF-8 bytes. A literal stays free. A disabled level drops before this handler even builds the
message.

## Topics

### Creating a handler

- ``OSLogHandler/init(subsystem:category:)``
