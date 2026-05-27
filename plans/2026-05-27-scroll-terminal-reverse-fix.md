# Scroll Terminal Reverse Fix

**Goal:** Remove the short reverse scroll that appears at the end of some two-finger scroll gestures.

**Root Cause:** Host logs showed the iOS client no longer emits momentum reports, but still sometimes sends a final `scroll.changed` report with a reversed `dy` and a large cross-axis `dx` immediately before `scroll.ended`. This happens when UIKit reports a `touchesMoved` sample containing only one remaining finger before the matching `touchesEnded`. The mapper compared that single point against the previous two-finger centroid, creating a synthetic reverse delta.

## Tasks

- [x] Inspect reproduced host scroll logs and identify the terminal reverse pattern.
- [x] Add a regression test for a two-finger scroll that receives a one-contact move before end.
- [x] Ignore one-contact move samples while an active gesture is still classified as two-finger.
- [x] Run the iOS touch mapper test suite.
- [x] Run shared protocol/package tests.
- [x] Rebuild, install, and launch the iOS app on the connected real device.
- [ ] Manually verify the two-finger scroll tail no longer reverses on a real iPad.

## Verification

- `swift test` passed in `apps/ios/TrackpadIOSCore` with 39 tests.
- `swift test` passed in `packages/TrackpadKit` with 23 tests.
- iOS real-device `xcodebuild` passed. The build still reports the existing orientation warning.
- `xcrun devicectl device install app` installed `com.trackpad.ios` on the connected device.
- `xcrun devicectl device process launch` launched `com.trackpad.ios`.
