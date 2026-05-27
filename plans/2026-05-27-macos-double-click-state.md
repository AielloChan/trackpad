# macOS Double-Click State Plan

**Goal:** Make consecutive iOS single-finger taps behave like native macOS double-clicks so text selection and other double-click actions work.

**Architecture:** Keep the iOS protocol as semantic `tap` events. The macOS host maps consecutive taps into mouse click counts using the host system double-click interval, then injects CoreGraphics mouse events with the matching click state.

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
