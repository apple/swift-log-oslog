# OSLog bridge benchmark

A [package-benchmark](https://github.com/ordo-one/package-benchmark) suite for the swift-log to `OSLogHandler`
bridge. It measures instructions and allocations. os_log's own work runs asynchronously and out-of-process, so
these numbers are the in-process overhead swift-log adds over a native os_log call, not end-to-end wall-clock
time.

## Running

```bash
swift package --allow-writing-to-package-directory benchmark
```

## Benchmarks

- `pure_oslog`: native `os.Logger`, no swift-log.
- `pure_oslog_dynamic_string`: native `os.Logger` logging a runtime `String`, as a dynamic `%{public}s`
  argument. Isolates the one allocation the bridge shows on a no-metadata log as os_log's, not swift-log's.
- `pure_oslog_repeated_context_multiple_emissions`: the pure-os_log take on the scoped scenario. `os.Logger`
  has no scoped metadata, so this re-specifies the 24 context fields inline, as 24 dynamic `%{public}s`
  arguments, on every emission.
- `bridge_no_metadata`: the bridge with a constant message and no metadata.
- `bridge_emission_time_metadata`: the bridge with a metadata field passed at the log call.
- `bridge_base_metadata`: the field set on the handler once. Exercises `OSLogHandler`'s cached base-metadata
  partition.
- `bridge_base_and_emission_metadata`: base context and an emission-time field on the same log. Combines the
  base and emission-time partitions.
- `bridge_large_base_and_emission_metadata`: the same, with a large base. Measures how that per-emission cost
  grows with base size.
- `bridge_scope_large_base_multiple_emissions`: a `withLogger(mergingMetadata:)` scope that accrues the large
  base once, then emits several statements inside it. Folds in the scope setup cost, amortized over the
  emissions.
