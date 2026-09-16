# Testing redaction

Verify both that ``RedactionLogHandler`` is on and the metadata value.

## Overview

`Sensitivity` is applied for each value at the call site.
Only checking that a redaction handler is enabled will not catch a field that misses a `sensitivity:` tag, or carries the wrong one.
Likewise, only verifying that a value has the `.sensitive` attribute is not enough either.
To validate that redaction is enabled and happening properly, assert both together.
Using the real handler chain, run the log and check the sink for `<redacted>`.

> Note: This checks that a component's values redact correctly. It does not prove the app installs a
> sensitivity-aware handler in the first place, such as ``RedactionLogHandler`` or one of your own. Test that
> separately, as part of your app's own configuration tests.

Code that logs either takes a `Logger` parameter or reads `Logger.current`. Test both the same way. Wrap a sink
in ``RedactionLogHandler``, run the log, and check the sink for `<redacted>`.

```swift
import InMemoryLogging
import Logging
import SensitivityAttribute
import Testing

struct LoginService {
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
        factory: { _ in RedactionLogHandler(wrapping: explicitSink) }
    )
    LoginService().login(userID: "u-123", logger: explicitLogger)
    #expect(explicitSink.entries[0].metadata["user.id"]?.description == "<redacted>")
    #expect(explicitSink.entries[0].metadata["action"]?.description == "password")

    let taskLocalSink = InMemoryLogHandler()
    withLogger(handler: RedactionLogHandler(wrapping: taskLocalSink)) { _ in
        LoginService().login(userID: "u-123")
    }
    #expect(taskLocalSink.entries[0].metadata["user.id"]?.description == "<redacted>")
    #expect(taskLocalSink.entries[0].metadata["action"]?.description == "password")
}
```
