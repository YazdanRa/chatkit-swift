# Contributing

This repository contains a standalone Swift package at the repository root. The goal is to keep the package small, native, protocol-compatible with ChatKit, and easy to embed in SwiftUI apps.

## Prerequisites

- macOS with Xcode and the Swift 6.3 toolchain
- Git
- Prek, SwiftLint 0.63.2, and SwiftFormat 0.61.1 when running hooks locally
- Network access only if future dependencies or backend integration tests require it

No Makefile, SwiftFormat config, or PR template is currently present. If those config files are added later, run the repo-specific checks before opening a pull request.

## Setup

Clone the repository and enter the package root:

```bash
git clone <repo-url>
cd chatkit-swift
```

Build and test:

```bash
swift test -Xswiftc -warnings-as-errors
```

Open in Xcode when you need previews, platform diagnostics, or simulator validation:

```bash
open Package.swift
```

## Package Layout

```text
Package.swift
Sources/ChatKitSwift/
  ChatKitView.swift             SwiftUI entry point
  ChatKitSession.swift          main-actor session controller
  ChatKitOptions.swift          public configuration surface
  ChatKitProtocol.swift         request protocol models
  ChatKitEvents.swift           streaming event models
  ChatKitThreadModels.swift     thread and item models
  ChatKitHTTPTransport.swift    default HTTP and SSE transport
  ChatKitWidget*.swift          widget model and rendering
Tests/ChatKitSwiftTests/
```

## Development Workflow

1. Start from a clean understanding of the current tree.

   ```bash
   git status --short
   ```

2. Keep changes scoped to the behavior you are touching. Avoid unrelated refactors.

3. Add or update tests with the behavior change. Prefer focused tests for protocol encoding, streaming event parsing, session state transitions, and transport behavior.

4. Run the package checks before marking work done.

   ```bash
   swift test -Xswiftc -warnings-as-errors
   ```

5. From the repository root, review the diff for accidental churn.

   ```bash
   git diff -- README.md CONTRIBUTING.md Package.swift Sources Tests .gitignore
   ```

## Code Standards

- Use SwiftUI and Swift concurrency directly. Do not add UIKit or AppKit dependencies to the package unless there is a deliberate platform-specific API boundary.
- SwiftLint uses `.swiftlint.baseline` for existing violations so hook adoption does not require unrelated source churn. Pull requests run `prek run --all-files` in GitHub Actions.
- Keep observable UI state in `@Observable` main-actor models or SwiftUI value state.
- Keep public API types `Sendable` where possible.
- Preserve unknown protocol fields with `JSONValue` or raw payload storage when compatibility matters.
- Keep transport code separate from view code.
- Keep backend secrets out of the app. ChatKitSwift should only receive user-scoped auth headers, short-lived client secrets, or app backend URLs.
- Prefer small, explicit types over stringly typed call sites in public APIs.
- Add comments only where the code is not self-explanatory.

## Testing

Run the full suite:

```bash
swift test -Xswiftc -warnings-as-errors
```

Run one test case while iterating:

```bash
swift test --filter ChatKitSessionTests
```

Useful areas to cover:

- `ChatKitRequest` JSON encoding
- `ChatKitEvent` JSON decoding
- SSE line parsing and multi-line event payloads
- `ChatKitSession` state changes for create, update, retry, feedback, and errors
- Widget root and component updates
- Custom transport integration

## Documentation Changes

Documentation should describe the current package behavior, not aspirational behavior. When adding examples:

- Import every module the snippet needs.
- Use public APIs that exist in `Sources/ChatKitSwift`.
- Keep OpenAI API keys server-side in every example.
- Mention host-app responsibilities for platform features such as file picking, microphone permissions, and upload byte transfer.

## Commit Messages

Use conventional commit messages:

```text
feat(scope): add widget action handling
fix(transport): cancel stream task on termination
docs(readme): document backend contract
test(session): cover client tool output flow
```

Use a breaking-change marker when needed:

```text
feat(api)!: rename thread action callbacks
```

Include a body when the change needs context, migration notes, or verification details.

## Pull Request Checklist

Before opening a pull request:

- The change is scoped to the requested behavior.
- New or changed behavior has tests.
- `swift test -Xswiftc -warnings-as-errors` passes from the repository root.
- Public API changes are documented in `README.md` when user-facing.
- Examples do not expose secrets or suggest putting OpenAI API keys in client apps.
- `git status --short` only shows intentional files.
- The PR title uses a conventional commit style.

If a `.github/pull_request_template.md` or additional contributor rules are added later, follow those as the source of truth.
