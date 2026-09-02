# RedactionLogHandler benchmark

A [package-benchmark](https://github.com/ordo-one/package-benchmark) suite for `RedactionLogHandler` in
`.redacting` mode. It measures instructions and allocations.

## Running

```bash
swift package --allow-writing-to-package-directory benchmark
```

## Benchmarks

- `redacting_{0,2,4}_of_4`: benchmarks `log(event:)`, with 0, 2, or 4 of 4 values sensitive.
