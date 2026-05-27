# Scroll Tap Suppression Plan

**Goal:** Prevent accidental left-clicks caused by staggered iOS touch release callbacks immediately after two-finger scrolling.

**Architecture:** Keep suppression in `TouchSurfaceEventMapper` because it is gesture-normalization behavior. Suppress only single-finger tap recognition for a short window after a two-finger scroll ends. Pointer movement and normal taps outside the window remain unchanged.

**Status:** Completed on 2026-05-27.

## Chunk 1: Tests

- [x] Add a failing mapper test that a single-finger tap starting within 80 ms after two-finger scroll release emits no left click.
- [x] Add a mapper test that a single-finger tap after the suppression window still emits a normal left click.

## Chunk 2: Implementation

- [x] Track a short single-tap suppression deadline after two-finger scroll end.
- [x] Carry suppression state through the single-finger gesture that begins inside the window.
- [x] Keep tap-then-quick-second-press drag behavior unaffected outside the suppression window.

## Chunk 3: Verification

- [x] Run `TrackpadIOSCore` tests.
- [x] Build `TrackpadIOS`.
- [x] Update `TODOS.md` and `docs/ios-client-mvp.md`.

## Verification Result

```text
apps/ios/TrackpadIOSCore swift test: 29 tests passed
xcodebuild TrackpadIOS Debug iPhone 17 simulator: BUILD SUCCEEDED
```
