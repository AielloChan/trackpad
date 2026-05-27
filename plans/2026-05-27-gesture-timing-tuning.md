# Gesture Timing Tuning Plan

**Goal:** Reduce accidental drag recognition by shortening the tap-then-second-press drag interval, and expose gesture timing thresholds in the iOS connected bar for fast real-device tuning. Real-device tuning later settled the default drag interval at 140 ms.

**Architecture:** Keep timing thresholds in `TouchSurfaceEventMapper` as platform-neutral gesture configuration. The iOS app owns live tuning UI and pushes the current configuration into the mapper before processing touch events.

**Status:** Completed on 2026-05-27.

## Chunk 1: Tests

- [x] Add a failing mapper test that a second press after the default 140 ms drag window does not start drag.
- [x] Update the positive tap-then-second-press drag test to use a press inside the shorter default window.
- [x] Add a mapper test that custom drag interval configuration can allow a longer second-press delay.

## Chunk 2: Core Implementation

- [x] Add reusable gesture timing configuration to `TouchSurfaceEventMapper`.
- [x] Change default tap-drag interval to 140 ms after real-device tuning.
- [x] Make tap maximum duration and scroll tap suppression interval configurable.

## Chunk 3: iOS UI Wiring

- [x] Add published gesture timing values to `TrackpadClientModel`.
- [x] Apply the current gesture timing configuration before mapper calls.
- [x] Add connected-bar sliders for tap, drag, and scroll guard timing.

## Chunk 4: Verification

- [x] Run `TrackpadIOSCore` tests.
- [x] Build `TrackpadIOS`.
- [x] Update `TODOS.md` and `docs/ios-client-mvp.md`.

## Verification Result

```text
apps/ios/TrackpadIOSCore swift test: 31 tests passed
xcodebuild TrackpadIOS Debug iPhone 17 simulator: BUILD SUCCEEDED
```
