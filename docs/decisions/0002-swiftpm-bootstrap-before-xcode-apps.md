# 0002: SwiftPM Bootstrap Before Native Xcode App Projects

Date: 2026-05-26

## Status

Accepted

## Context

The repository is starting from an empty folder. The first engineering risk is not visual app scaffolding, but whether the shared protocol and macOS input-injection path can compile and be tested quickly.

Creating hand-written `.xcodeproj` files is brittle, and no project generator has been adopted yet.

## Decision

Bootstrap shared code and the macOS host spike with Swift Package Manager first:

- `packages/TrackpadKit` is a library package with focused targets.
- `apps/macos/TrackpadHost` is an executable Swift Package that Xcode can open directly.
- Native iOS and macOS app projects remain a follow-up task once the core event and host spike are stable.

## Consequences

- Protocol and host-core logic are testable immediately with `swift test`.
- The macOS spike can expose command-line debug actions for permission and input-injection checks.
- A future app project should depend on these packages instead of duplicating logic.

