# Pointer Small Move Threshold Plan

**Goal:** Remove the apparent pointer dead zone after a tap when the next press is a potential tap-drag gesture.

**Architecture:** Keep drag detection in `TouchSurfaceEventMapper`, but do not block pointer movement while waiting to decide whether the movement becomes a drag. Small movements should still emit pointer move events; crossing the drag threshold should add the left-button down event.

**Status:** Completed on 2026-05-27.

## Chunk 1: Tests

- [x] Add a failing mapper test that small movement during a tap-drag candidate still emits pointer movement.
- [x] Keep the existing tap-then-second-press drag behavior for movement past the drag threshold.

## Chunk 2: Implementation

- [x] Remove the early return that swallows small pointer movement during tap-drag candidate detection.
- [x] Emit pointer move normally before the drag threshold.
- [x] Continue emitting left-button down once the drag threshold is crossed.

## Chunk 3: Verification

- [x] Run `TrackpadIOSCore` tests.
- [x] Build `TrackpadIOS`.
- [x] Update `TODOS.md` and `docs/ios-client-mvp.md`.

## Verification Result

```text
apps/ios/TrackpadIOSCore swift test: 32 tests passed
xcodebuild TrackpadIOS Debug iPhone 17 simulator: BUILD SUCCEEDED
```
