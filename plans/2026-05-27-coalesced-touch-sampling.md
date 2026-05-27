# Coalesced Touch Sampling Plan

**Goal:** Reduce the apparent one-finger pointer jump at gesture start by forwarding UIKit coalesced touch samples instead of only the final delivered touch.

**Root Cause:** `UIKitTouchSurfaceView.touchesMoved` currently forwards `event.allTouches`, which gives the last touch in UIKit's coalesced sequence. On devices that sample touch input faster than UIKit delivers responder events, the first visible pointer move can therefore contain the accumulated movement since touch begin.

**Status:** Completed on 2026-05-27.

## Chunk 1: Investigation

- [x] Confirm `TouchSurfaceEventMapper` does not suppress one-finger pointer movement.
- [x] Confirm the send buffer does not discard pointer move frames.
- [x] Confirm macOS CGEvent pointer injection preserves fractional positions.
- [x] Check Apple UIKit documentation for coalesced touch delivery behavior.

## Chunk 2: Implementation

- [x] Forward coalesced single-finger move samples from `UIKitTouchSurfaceView`.
- [x] Keep the existing multi-touch path unchanged until two-finger coalesced alignment is designed.
- [x] Document the iOS sampling behavior.

## Chunk 3: Verification

- [x] Build the iOS app.
- [x] Run iOS core tests.
- [x] Update `TODOS.md`.

## Verification Result

```text
apps/ios/TrackpadIOSCore swift test: 34 tests passed
xcodebuild TrackpadIOS Debug iPhone 17 simulator: BUILD SUCCEEDED
```
