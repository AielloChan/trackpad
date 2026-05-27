# iOS Tuning Controls Plan

**Goal:** Make momentum last longer by default and expose connected-bar sliders for pointer speed and momentum amount.

**Architecture:** Keep tuning on the iOS client side. Pointer speed scales only pointer movement events before transport. Momentum amount scales only the initial velocity used by the momentum planner.

**Status:** Completed on 2026-05-27.

## Chunk 1: Core Tuning Tests

- [x] Add tests that default momentum creates a longer sequence.
- [x] Add tests that momentum amount scales velocity-generated steps.
- [x] Add tests that pointer-speed scaling affects pointer moves only.

## Chunk 2: Core Tuning Implementation

- [x] Tune `ScrollMomentumPlanner` defaults for longer deceleration.
- [x] Add `amount` to velocity-based momentum planning.
- [x] Add reusable input-event tuning for pointer speed.

## Chunk 3: iOS UI Wiring

- [x] Add `pointerSpeedMultiplier` and `scrollMomentumAmount` to `TrackpadClientModel`.
- [x] Apply pointer scaling before events are enqueued.
- [x] Apply momentum amount when starting scroll momentum.
- [x] Add connected-bar sliders for pointer speed and momentum amount.

## Chunk 4: Verification

- [x] Run `TrackpadIOSCore` tests.
- [x] Build `TrackpadIOS`.
- [x] Update `TODOS.md` and `docs/ios-client-mvp.md`.

## Verification Result

```text
apps/ios/TrackpadIOSCore swift test: 27 tests passed
xcodebuild TrackpadIOS Debug iPhone 17 simulator: BUILD SUCCEEDED
```
