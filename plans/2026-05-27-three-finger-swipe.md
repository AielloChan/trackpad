# Three-Finger Swipe Gestures

**Goal:** Add the first system-level multi-finger gestures by recognizing three-finger swipes on iOS and mapping them to macOS system navigation actions.

**Scope:**

- Three-finger swipe up -> Mission Control.
- Three-finger swipe down -> App Expose.
- Three-finger swipe left -> next Space / full-screen app.
- Three-finger swipe right -> previous Space / full-screen app.

**Non-goals:**

- Native Magic Trackpad HID emulation.
- Continuous Mission Control or Spaces animations that track finger position.
- Three-finger drag mode.
- Three-finger lookup or four-touch pinch/spread gestures.

## Tasks

- [x] Add protocol-level system action events and binary reports.
- [x] Add iOS mapper tests for three-finger swipe direction detection and one-shot emission.
- [x] Add macOS mapper tests for system action command mapping.
- [x] Implement iOS three-finger swipe recognition.
- [x] Implement macOS keyboard shortcut injection for system actions.
- [x] Gate macOS system actions with the host Mac's current three-finger trackpad settings.
- [x] Fix macOS Space navigation to prefer the display under the current pointer.
- [x] Suppress accidental single-finger taps immediately after a three-finger system gesture.
- [x] Suppress residual reverse Space actions and two-finger taps immediately after a three-finger system gesture.
- [x] Replace direct managed Spaces switching with `Control-Left` and `Control-Right` keyboard shortcut injection for left/right swipes.
- [x] Diagnose macOS Automation denial for the `System Events` Space-switching path.
- [x] Add an explicit host app Automation permission status and request action.
- [x] Keep three-finger gesture sessions active until all touches lift, with one system action per session.
- [x] Update protocol and project documentation.
- [x] Run package, iOS core, and macOS host tests.
- [x] Build the iOS app for the connected real device.
- [x] Manually verify gestures on a real iPhone/iPad against macOS.

## Verification

- `swift test` passed in `packages/TrackpadKit` with 25 tests.
- `swift test` passed in `apps/ios/TrackpadIOSCore` with 41 tests.
- `swift test` passed in `apps/macos/TrackpadHost` with 27 tests.
- `xcodebuild` passed for `TrackpadHostApp`.
- macOS host reads `TrackpadThreeFingerVertSwipeGesture`, `TrackpadThreeFingerHorizSwipeGesture`, and `TrackpadThreeFingerDrag`; current local values are vertical `2`, horizontal `2`, drag `0`.
- `swift test` passed in `apps/macos/TrackpadHost` with 35 tests after adding pointer-display Space selection coverage.
- `swift test` passed in `apps/ios/TrackpadIOSCore` with 42 tests after adding three-finger post-gesture tap suppression coverage.
- `swift test` passed in `apps/ios/TrackpadIOSCore` with 44 tests after adding residual reverse Space and two-finger tap suppression coverage.
- Direct `CGSManagedDisplaySetCurrentSpace` switching was removed from the host because it did not match the requested `Control-Left` / `Control-Right` behavior.
- Direct CGEvent `Control-Left` / `Control-Right` posting was verified not to switch Spaces on the local Mac, while `System Events` can trigger the same shortcuts when Automation permission is granted.
- `TrackpadHostApp` now declares `NSAppleEventsUsageDescription`, exposes Automation permission status, and can request access to control `System Events`.
- Real-device verification confirmed three-finger left/right Space switching works after granting Automation permission.
- iOS now keeps a three-finger session alive until every touch lifts. A single moving contact stays mapped to pointer movement; at least two contacts must move far enough to trigger the single system action allowed for that session.
- `xcodebuild` passed for the connected iOS device. The build still reports the existing orientation warning.
- `xcrun devicectl device install app` installed `com.trackpad.ios` on the connected device.
- Automatic iOS launch was blocked because the device was locked.
