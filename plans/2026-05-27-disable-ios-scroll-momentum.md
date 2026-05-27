# Disable iOS Scroll Momentum

**Goal:** Remove the current iOS-generated inertial scroll implementation because real-device testing shows it can still create large unintended jumps, including sudden scrolling back to the beginning.

**Decision:** Keep protocol-level `momentumPhase` compatibility and macOS support, but stop the iOS client from calculating or emitting synthetic momentum events. The client should send only direct finger scroll events and a final scroll-ended event.

## Tasks

- [x] Remove iOS client momentum amount state and connected-bar slider.
- [x] Remove iOS scroll seed tracking and scheduled momentum event generation.
- [x] Remove reusable iOS momentum planner and seed tracker code.
- [x] Remove tests that covered the disabled momentum implementation.
- [x] Update project status docs and TODOs.
- [x] Rebuild and install the iOS client for real-device verification.
- [ ] Manually verify two-finger scroll release no longer causes sudden inertial jumps.

## Verification

- `swift test` passed in `apps/ios/TrackpadIOSCore` with 38 tests.
- `swift test` passed in `packages/TrackpadKit` with 23 tests.
- `swift test` passed in `apps/macos/TrackpadHost` with 26 tests.
- iOS real-device build passed. The build still reports the existing orientation warning.
- iOS app install to the connected iPad succeeded in a later build, and `xcrun devicectl device process launch` launched `com.trackpad.ios`.
