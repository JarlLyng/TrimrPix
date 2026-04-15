# Contributing to TrimrPix

We welcome contributions! Whether it's bug reports, feature requests, or pull requests — all help is appreciated.

## Getting Started

1. Fork the repository
2. Clone your fork
3. Open `TrimrPix.xcodeproj` in Xcode 16+
4. Build and run (requires macOS 15.2+)

## Development Setup

- **Swift 5.9+** with `any` keyword for protocol types
- **SwiftUI** for all views
- **MVVM architecture** — see [ARCHITECTURE.md](ARCHITECTURE.md) for details
- **Design tokens** from [iamjarl-design](https://github.com/JarlLyng/iamjarl-design) package

## Before Submitting a PR

- Follow the guidelines in [CODE_STYLE.md](CODE_STYLE.md)
- Use dependency injection via protocols (see `Protocols.swift`)
- Add logging for important operations via `LoggerProtocol`
- Handle errors through `TrimrPixError` enum
- Update [ARCHITECTURE.md](ARCHITECTURE.md) if you change core components
- Link any related GitHub Issues in your PR description

## Reporting Bugs

Open a [GitHub Issue](https://github.com/JarlLyng/TrimrPix/issues/new) with:

- macOS version
- TrimrPix version
- Steps to reproduce
- Expected vs. actual behavior
- Sample image (if relevant and non-private)

## Feature Requests

Open a [GitHub Issue](https://github.com/JarlLyng/TrimrPix/issues/new) describing:

- What you'd like to see
- Why it would be useful
- Any ideas for implementation

## Code of Conduct

Be respectful and constructive. We're all here to make TrimrPix better.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
