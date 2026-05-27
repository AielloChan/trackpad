# Gesture Polish Plan

**Goal:** Fix the first real-device gesture issues: live window dragging, accidental click after two-finger scroll, and missing scroll momentum.

## Chunk 1: Live Drag

- [x] Add host mapper test for pointer movement while the left button is down.
- [x] Track pressed mouse button state in `MacInputMapper`.
- [x] Inject dragged mouse events instead of normal moved events while dragging.

## Chunk 2: Two-Finger End Handling

- [x] Add iOS mapper test for two-finger scroll ending when one contact remains.
- [x] End the existing two-finger gesture as soon as contact count drops below two.
- [x] Ensure the final one-finger release after a scroll does not emit a left click.

## Chunk 3: Scroll Momentum

- [x] Add tests for a reusable scroll momentum planner.
- [x] Generate decaying post-release scroll steps from the last non-zero scroll delta.
- [x] Schedule momentum steps from the iOS client model after a scroll end.

## Chunk 4: Verification

- [x] Run `TrackpadIOSCore` tests.
- [x] Run `TrackpadHost` tests.
- [x] Run `TrackpadKit` tests.
- [x] Build `TrackpadIOS`.
- [x] Build and relaunch `TrackpadHostApp`.
- [x] Update `TODOS.md` and `docs/ios-client-mvp.md`.

## Verification Result

```text
apps/ios/TrackpadIOSCore swift test: 20 tests passed
apps/macos/TrackpadHost swift test: 15 tests passed
packages/TrackpadKit swift test: 12 tests passed
xcodebuild TrackpadIOS Debug iPhone 17 simulator: BUILD SUCCEEDED
xcodebuild TrackpadHostApp Debug: BUILD SUCCEEDED
TrackpadHostApp relaunched from DerivedData, PID 62652
```
