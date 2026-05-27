# Basic iOS Gesture Implementation Plan

**Goal:** Add the first practical trackpad gestures after pointer movement: single-finger click, tap-then-quick-second-press drag, two-finger right click, and two-finger scroll.

**Architecture:** Keep gesture normalization in `TrackpadIOSCore`. UIKit should only convert `UITouch` instances into platform-neutral contacts and forward them to the app model.

## Chunk 1: Gesture Mapper

- [x] Add tests for single-finger tap.
- [x] Add tests that hold-and-move remains pointer movement.
- [x] Add tests for tap-then-quick-second-press drag button down / move / button up.
- [x] Add tests for two-finger tap.
- [x] Add tests for two-finger scroll phases.
- [x] Implement platform-neutral contact mapping.

## Chunk 2: iOS App Wiring

- [x] Forward multiple UIKit touches into the model.
- [x] Send all mapper-emitted events.
- [x] Keep existing single-finger movement behavior.

## Chunk 3: Verification

- [x] Run `TrackpadIOSCore` tests.
- [x] Run `TrackpadKit` tests.
- [x] Run `TrackpadHost` tests.
- [x] Build `TrackpadIOS` simulator target.
- [x] Update `TODOS.md` and `docs/ios-client-mvp.md`.

## Verification Result

```text
apps/ios/TrackpadIOSCore swift test: 14 tests passed
packages/TrackpadKit swift test: 10 tests passed
apps/macos/TrackpadHost swift test: 13 tests passed
xcodebuild TrackpadIOS simulator target: BUILD SUCCEEDED
```
