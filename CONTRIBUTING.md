## Legal

By submitting a pull request, you represent that you have the right to license
your contribution to Apple and the community, and agree by submitting the patch
that your contributions are licensed under the Apache 2.0 license (see
`LICENSE.txt`).

## AI tools

Human discourse is an essential part of open source development. To encourage productive collaboration between contributors and maintainers, please refrain from using AI tools for the following:

- Issues: titles, bodies, and comments.
- Pull requests: titles, descriptions, and comments.
- Proposals.

Contributors who feel more comfortable writing in another language may use automated translation tools, but must include their original content in their preferred language.

## How to submit a bug report

Please report any issues related to this library in the [swift-log-oslog](https://github.com/apple/swift-log-oslog/issues) repository.

Specify the following:

* SwiftLog OSLog version
* Contextual information (e.g. what you were trying to achieve with swift-log-oslog)
* Simplest possible steps to reproduce
  * The more complex the steps are, the lower the priority will be.
  * A pull request with failing test case is preferred, but it's just fine to paste the test case into the issue description.
* Anything that might be relevant in your opinion, such as:
  * Swift version or the output of `swift --version`
  * OS version and the output of `uname -a`
  * Network configuration

### Example

```
SwiftLog OSLog commit hash: 4fe877816ad82627602377f415b6a66850214824

Context:
While testing my application that uses with SwiftLog OSLog, I noticed that ...

Steps to reproduce:
1. ...
2. ...
3. ...
4. ...

$ swift --version
Swift version 4.0.2 (swift-4.0.2-RELEASE)
Target: x86_64-unknown-linux-gnu

Operating system: Ubuntu Linux 16.04 64-bit

$ uname -a
Linux beefy.machine 4.4.0-101-generic #124-Ubuntu SMP Fri Nov 10 18:29:59 UTC 2017 x86_64 x86_64 x86_64 GNU/Linux

My system has IPv6 disabled.
```

## Contributing a pull request

> Important: To ensure productive use of contributor and maintainer time and resources, contributors must first agree their proposed change with a maintainer in an issue. Pull requests opened without prior discussion may be closed without review.

If there is no issue already tracking the problem or feature request, please file a new one using your own voice (see "AI tools" usage above).

Once an issue is assigned to you, follow these steps:

1. Review the [Developing SwiftLog OSLog](https://swiftpackageindex.com/apple/swift-log-oslog/documentation/configuration/development) documentation.
2. Prepare your change, keeping in mind that a good patch is:
  - Concise, and contains as few changes as needed to achieve the end result.
  - Tested, ensuring that any tests provided failed before the patch and pass after it.
  - Documented, adding API documentation as needed to cover new functions and properties.
  - Accompanied by a great commit message.
3. Open a pull request at https://github.com/apple/swift-log-oslog and wait for code review by the maintainers.

## Benchmarks

Benchmarks for `swift-log-oslog` are in two separate Swift packages: `Benchmarks/OSLog` and `Benchmarks/Redaction`.
They use the [`ordo-one/benchmark`](https://github.com/ordo-one/benchmark) plugin.
An installation guide can be found in the [Getting Started article](https://swiftpackageindex.com/ordo-one/benchmark/documentation/benchmark/gettingstarted#Installing-Prerequisites-and-Platform-Support) of `package-benchmark`.
Afterwards you can run the benchmarks from CLI by going to one of the two package folders (for example `cd Benchmarks/OSLog`) and invoking:
```
swift package --disable-sandbox --allow-writing-to-package-directory benchmark
```

For more information please refer to `swift package benchmark --help` or the [documentation of `package-benchmark`](https://swiftpackageindex.com/ordo-one/package-benchmark/documentation/benchmark).

## Automated release process

This repository uses automated releases based on semantic versioning labels. See the [Auto Release Workflow documentation](https://github.com/apple/swift-temporal-sdk/blob/main/.github/workflows/README.md) for details.
