# OSLog bridge benchmark

A [package-benchmark](https://github.com/ordo-one/package-benchmark) suite for the swift-log → `OSLogHandler` bridge,
measuring **instructions** and **allocations**. os_log's own work is asynchronous and out-of-process, so these are the
in-process overhead swift-log adds over a native os_log call — not end-to-end wallclock.

## Running

```bash
swift package --allow-writing-to-package-directory benchmark
```

## Benchmarks

- `pure_oslog` — native `os.Logger`, no swift-log.
- `pure_oslog_dynamic_string` — native `os.Logger` logging a *runtime* `String` (a dynamic `%{public}s` arg); isolates
  the one allocation the bridge shows on a no-metadata log as os_log's, not swift-log's.
- `pure_oslog_repeated_context_multiple_emissions` — the pure-os_log take on the scoped scenario: os_log has no
  scoped metadata, so the 24 context fields are re-specified inline (24 dynamic `%{public}s` args) on every emission.
- `bridge_no_metadata` — the bridge with a constant message and no metadata.
- `bridge_emission_time_metadata` — the bridge with a metadata field passed at the log call.
- `bridge_base_metadata` — the field set on the handler once, exercising `OSLogHandler`'s cached base-metadata
  partition.
- `bridge_base_and_emission_metadata` — base context *and* an emission-time field on the same log; the case that
  combines the base and emission-time partitions (the cached base string is copied to append the emission-time part).
- `bridge_large_base_and_emission_metadata` — the same with a large base, measuring how that per-emission cost grows
  with base size.
- `bridge_scope_large_base_multiple_emissions` — a `withLogger(mergingMetadata:)` scope that accrues the large base
  once, then emits several statements within it; folds in the scope setup cost amortized over the emissions.
