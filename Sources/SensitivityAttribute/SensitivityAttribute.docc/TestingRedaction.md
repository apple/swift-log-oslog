# Testing redaction

Verify a single metadata value, not just that ``RedactionLogHandler`` is on.

## Overview

`Sensitivity` is tagged per value at the call site. Checking only that redaction is on will not catch a field
that misses a `sensitivity:` tag, or carries the wrong one. Checking only that a value carries the `.sensitive`
attribute is not enough either. Most handlers ignore attributes and log the value anyway. Assert on both
together, through the real handler chain. Run the log. Then check the sink for `<redacted>`.

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
        factory: { _ in RedactionLogHandler(mode: .redacting, wrapping: explicitSink) }
    )
    LoginService().login(userID: "u-123", logger: explicitLogger)
    #expect(explicitSink.entries[0].metadata["user.id"]?.description == "<redacted>")
    #expect(explicitSink.entries[0].metadata["action"]?.description == "password")

    let taskLocalSink = InMemoryLogHandler()
    withLogger(handler: RedactionLogHandler(mode: .redacting, wrapping: taskLocalSink)) { _ in
        LoginService().login(userID: "u-123")
    }
    #expect(taskLocalSink.entries[0].metadata["user.id"]?.description == "<redacted>")
    #expect(taskLocalSink.entries[0].metadata["action"]?.description == "password")
}
```
