# Mission Control Tap-Then-Drag

## Goal

Allow `TapThenDrag` to drag Mission Control window thumbnails to another Space without the first tap immediately selecting the window and exiting Mission Control.

## Scope

- Keep the protocol unchanged.
- Change the iOS mapper so one-finger taps are held locally until the tap-drag interval expires.
- Cancel the pending tap when a quick second press moves into drag.
- Flush the pending tap from the iOS app with a short timer so ordinary `LeftClickTap` still works.
- Document the behavior and add manual verification tracking.

## Progress

- [x] Add failing mapper coverage for delayed tap flushing and tap-then-drag cancellation.
- [x] Implement pending tap storage and expiry flushing in `TouchSurfaceEventMapper`.
- [x] Connect pending tap flushing to the iOS app touch lifecycle.
- [x] Update gesture and protocol documentation.
- [x] Run package tests and app builds.
- [ ] Manually verify Mission Control window thumbnail dragging on a real iPhone/iPad.

## Verification

- `cd apps/ios/TrackpadIOSCore && swift test`
- Build `TrackpadIOS`.
- Manual: open Mission Control, tap a window thumbnail, quickly press again and drag upward to the Spaces strip, then drop it into another Space. The first tap must not exit Mission Control.
