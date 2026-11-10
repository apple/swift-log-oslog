# Welcome to the Swift Log OSLog community

Sensitivity-aware logging with swift-log: `SensitivityAttribute` works on any platform, and `OSLogHandler` logs to the
Darwin unified logging system.

We welcome contributors of all backgrounds and experience levels. A community with diverse perspectives builds
software with lasting impact.

- [How you can help](#how-you-can-help)
- [Setting up your environment](#setting-up-your-environment)
- [Submitting issues and pull requests](#submitting-issues-and-pull-requests)
- [Code of conduct](#code-of-conduct)
- [Legal](#legal)
- [Automated release process](#automated-release-process)

## How you can help

- Report bugs with clear, reproducible steps.
- Provide feedback on issues and pull requests based on your unique use case.
- Propose enhancements following the
  [Proposals process](Sources/OSLogHandler/OSLogHandler.docc/Proposals/Proposals.md).
- Improve documentation and API reference guides.
- Add tests covering edge cases.

Look for issues tagged [good first issue](#good-first-issues) to familiarize yourself with the project.

## Setting up your environment

The package supports the latest patch releases of the
[last three](https://github.com/swiftlang/project-operations/blob/main/github-policies.md#principles) minor official
Swift releases.

Clone the repository and run the tests:

```bash
git clone https://github.com/apple/swift-log-oslog.git
cd swift-log-oslog
swift test
```

## Submitting issues and pull requests

We maintain high standards to ensure quality across the project.

Your contributions are evaluated on:

- Technical quality and correctness.
- Adherence to existing conventions and architectural patterns.
- Demonstrated understanding of the implementation and its implications.
- Clarity of communication.
- Maintainability.

You may use productivity tools, including AI-assisted coding, to help you work more efficiently. However, you remain
fully accountable for all submitted code, issues, pull requests, and comments. AI-generated content must meet the same
standards as human-written contributions. Review, validate, and, as needed, refine or rearrange AI-assisted work so the
final contribution reflects your human creativity, understanding, and control. Use your voice and expression when
producing written materials. Misuse of AI tools in your contributions and conversations may be considered a violation
of our [Code of Conduct](https://github.com/apple/.github/blob/main/CODE_OF_CONDUCT.md).

### Issues

Before submitting an issue:

- Search [existing issues](https://github.com/apple/swift-log-oslog/issues) to avoid duplicates.
- Write a clear, concise title and a detailed description. Ensure all information is accurate and fully understood by
  you.
- Include precise steps to reproduce the issue, expected behavior, and actual behavior. Verify these steps yourself.
- Specify your environment, package version, and any relevant configurations. Include the output of
  `swift --version` and `uname -a`.
- Explain the severity and impact of the problem.
- For security issues, file a [security advisory](https://github.com/apple/swift-log-oslog/security). Do not open a
  public GitHub issue.

Please follow the [issue template](https://github.com/apple/swift-log-oslog/issues/new?template=bug_report.md) when you
describe the issue.

#### Good first issues

[Good first issues](https://github.com/apple/swift-log-oslog/contribute) are mentoring opportunities. They help you
learn the codebase, build your foundation as a contributor, and grow into an active participant in the community.

These issues are about the journey, not the fastest path to a solution. If you use AI-assisted tools on these issues,
use them in a way that supports your learning. Make sure you can explain your approach and that your work meets our
standards above.

#### Proposing features

We welcome feature requests. Describe the proposed changes needed and why they matter in an issue. Please do not start
with a pull request. When a new feature starts taking shape, follow the
[Proposals process](Sources/OSLogHandler/OSLogHandler.docc/Proposals/Proposals.md) to open a new
proposal and have an opportunity to discuss it with a broader community.

### Pull requests

**Important:** You should submit an issue and get maintainer acknowledgment before doing complex work, such as any API
or behavior change. Pull requests opened without prior discussion may be closed without review.

Pull requests represent proposed solutions or enhancements. When submitting a pull request, verify it meets these
expectations:

- Address the stated problem or feature request completely and effectively. You must fully understand and validate your
  proposed solution.
- Ensure the solution is thorough, handles edge cases, and integrates cleanly.
- Include comprehensive tests that validate your changes and prevent regressions.
- Follow the [pull request template](.github/PULL_REQUEST_TEMPLATE.md) when you describe your PR.
- Make sure [automated CI checks](#running-ci-jobs-locally) pass for your PR. Ask for guidance when unsure how to
  interpret CI results. CI runs automatically on every pull request. It builds and tests on macOS, Linux, Windows,
  Android, and Wasm, and it runs the benchmarks. Contributions from external contributors require maintainer approval to
  run workflows.

Not yet ready for a review, but want to share code changes in a discussion? Open a draft pull request. You can mark it
Ready for review later.

#### Pull request style guide and format

Follow our coding style and formatting to maintain a consistent, readable codebase.

- Conform to the established protocols and design patterns.
- The package depends on swift-log only. Discuss any new dependency in an issue first.
- Format code using `swift-format -r -i -p .` in the repository root before you push.
- Add the license header to every new source file. Copy it from an existing file.
- Write documentation that's clear and to the point. Explain the _why_ behind non-obvious decisions. Avoid repeated
  explanations and restating the implementation in prose.
- Write a clear and concise pull request description following the template and the
  [Code of Conduct](https://github.com/apple/.github/blob/main/CODE_OF_CONDUCT.md).

#### Testing

All contributions require thorough testing across all the platforms and Swift versions the package supports.

**Local testing**: Ensure all existing tests pass on your host platform before submitting:

```bash
swift test
```

The `OSLogHandler` tests run only on platforms that provide the `os` module, such as macOS.

**Automated tests**: New features and bug fixes require corresponding automated tests that validate the intended
behavior and prevent regressions. Changes that can affect performance also require benchmarks.

**Benchmarks**: The benchmark packages are in the `Benchmarks` directory. `Benchmarks/OSLog` measures `OSLogHandler`.
`Benchmarks/Redaction` measures `RedactionLogHandler`. They use the
[package-benchmark](https://github.com/ordo-one/package-benchmark) plugin. Follow its
[installation guide](https://swiftpackageindex.com/ordo-one/benchmark/documentation/benchmark/gettingstarted#Installing-Prerequisites-and-Platform-Support)
first. The benchmarks count instructions and allocations. They do not measure wall-clock time. Run one package with the
`--package-path` option:

```bash
swift package --package-path Benchmarks/OSLog benchmark
```

CI compares every benchmark with the p90 thresholds in the `Thresholds` directory of its package. The directory has one
subdirectory for each Swift version. A benchmark passes when its instructions stay within 10 percent of the threshold
and its allocation count stays equal. If a change moves a metric on purpose, update the thresholds and commit them with
the change. Check the thresholds:

```bash
swift package --package-path Benchmarks/OSLog benchmark thresholds check \
    --format metricP90AbsoluteThresholds --path "Benchmarks/OSLog/Thresholds/Xcode swift 6.4/"
```

Update the thresholds:

```bash
swift package --package-path Benchmarks/OSLog --allow-writing-to-package-directory benchmark thresholds update \
    --format metricP90AbsoluteThresholds --path "Benchmarks/OSLog/Thresholds/Xcode swift 6.4/"
```

For more information, see `swift package benchmark --help` and the
[documentation of package-benchmark](https://swiftpackageindex.com/ordo-one/package-benchmark/documentation/benchmark).

#### Running CI jobs locally

You can run the GitHub Actions workflows locally using [act](https://github.com/nektos/act). To run all the jobs that
run on a pull request, use the following command:

```bash
act pull_request
```

To run just a single job, use `workflow_call -j <job>`, and specify the inputs the job expects. For example, to run just
format check:

```bash
act workflow_call -j soundness --input format_check_enabled=true
```

## Code of conduct

We are committed to fostering a community where different experiences and perspectives come together to create and
collaborate. Good collaboration depends on honest feedback and respect for the time and effort every contributor brings
to this project. [Please review our Code of Conduct](https://github.com/apple/.github/blob/main/CODE_OF_CONDUCT.md); all
community members are expected to adhere to it.

## Legal

By submitting a pull request, you represent that you have the right to license your contribution to Apple and the
community, and agree by submitting the patch that your contributions are licensed under the Apache 2.0 license (see
`LICENSE.txt`).

## Automated release process

This repository uses automated releases based on semantic versioning labels. See the
[Auto Release Workflow documentation](https://github.com/apple/swift-temporal-sdk/blob/main/.github/workflows/README.md)
for details.
