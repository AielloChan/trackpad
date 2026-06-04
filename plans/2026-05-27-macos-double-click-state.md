# macOS Double-Click State Plan

**Goal:** Make explicit iOS double-tap gestures behave like native macOS double-clicks so text selection and other double-click actions work.

**Architecture:** Keep the iOS protocol as semantic `tap` events, but carry an explicit click count. The iOS mapper marks a second tap after the tap-drag window as `clickCount=2`; the macOS host injects CoreGraphics mouse events with that click state and does not promote ordinary consecutive taps on its own. A second tap inside the tap-drag window stays `clickCount=1` unless it moves into `TapThenDrag`, which avoids accidental double-clicks when the user meant to single-click.

**Follow-up:** On 2026-05-29, host-side automatic promotion was removed after real-device testing showed ordinary single taps could be treated as double-clicks too broadly.
**Follow-up:** On 2026-06-04, iOS-side double-click promotion was separated from the tap-drag candidate window after logs showed `tap(clickCount=1)` immediately followed by `tap(clickCount=2)` for accidental quick second touches.

## References

- Apple Support: trackpad gestures define tap/click behavior for Mac. https://support.apple.com/kb/ht4721
- Apple Developer: `NSEvent.clickCount` represents repeated click count. https://developer.apple.com/documentation/appkit/nsevent/clickcount
- Apple Developer: CoreGraphics `mouseEventClickState` carries the injected mouse click count. https://developer.apple.com/documentation/coregraphics/cgeventfield/mouseeventclickstate

## Chunk 1: Host Mapper Tests

- [x] Add a failing test that two taps within the host double-click interval map the second tap to click count 2.
- [x] Add a test that taps outside the interval reset click count to 1.

## Chunk 2: Host Implementation

- [x] Add click count to `MacInputCommand.button`.
- [x] Track consecutive tap count in `MacInputMapper`.
- [x] Reset tap count when pointer movement, button events, or stale tap intervals interrupt the sequence.
- [x] Set CoreGraphics `mouseEventClickState` when injecting button events.

## Chunk 3: Verification

- [x] Run `TrackpadHost` tests.
- [x] Build `TrackpadHostApp`.
- [x] Update `TODOS.md` and `docs/ios-client-mvp.md`.

## Verification Results

```text
swift test --filter MacInputMapperTests: 7 tests passed
swift test: 18 tests passed
xcodebuild -project apps/macos/TrackpadHostApp/TrackpadHostApp.xcodeproj -scheme TrackpadHostApp -configuration Debug build: BUILD SUCCEEDED
TrackpadHostApp relaunched from DerivedData, PID 53291
```
