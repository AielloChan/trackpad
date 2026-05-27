# Drag Dead Zone Plan

**Goal:** Remove the initial movement dead zone when using tap-then-quick-second-press drag.

**Status:** Implemented on 2026-05-27. Waiting for real-device feel verification.

**Diagnostic Follow-up:** Real-device testing reported an initial drag dead zone, so temporary `######### ios.mapper` diagnostics were used for tap-drag candidate detection, first-move rebasing, drag button-down emission, and mapper event output. Those high-frequency diagnostics were removed after the fix was verified.

**Log Finding:** The reproduced drag sequence showed the second press was correctly detected as `candidate=true`, but the first move jumped from `x=302.5 y=795.5` to `x=313 y=792.5`. After pointer speed tuning this became the host's first drag delta `dx=22.05 dy=-6.3`, so the perceived dead zone was a large landing-offset jump, not delayed macOS injection.

## Root Cause

`TouchSurfaceEventMapper` marks a quick second press as `isTapDragCandidate`, but it only emits the left-button down event after movement exceeds `tapMovementTolerance` (`8 pt`). During that initial movement the host receives plain pointer moves, so a window under the cursor does not move until the threshold is crossed.

## Intended Behavior

- A quick second press after a tap remains the gate for drag mode.
- Once a tap-drag candidate starts moving, emit left-button down before the first pointer move.
- A quick second press with no movement can still finish as a normal second tap.
- Non-candidate pointer movement keeps the first-move rebase behavior.

## Verification

- [x] Add/adjust mapper tests so a small first move in tap-drag candidate mode emits left-button down plus pointer move.
- [x] Run iOS core tests.
- [x] Build the iOS app target.
- [x] Install the latest iOS app on the connected iPad.
- [x] Add targeted mapper diagnostics after the real-device issue persisted.
- [x] Add mapper regression coverage for rebasing a large tap-drag first move while keeping drag active.
- [x] Rebuild and reinstall the corrected iOS app on the connected iPad.

## Verification Result

```text
apps/ios/TrackpadIOSCore swift test: 43 tests passed
xcodebuild TrackpadIOS Debug iPhone 17 simulator: BUILD SUCCEEDED
xcodebuild TrackpadIOS Debug connected iPad: BUILD SUCCEEDED
xcrun devicectl device install app connected iPad: installed `com.trackpad.ios`
xcrun devicectl device process launch connected iPad: launched `com.trackpad.ios`
```

Second verification after log-driven fix:

```text
apps/ios/TrackpadIOSCore swift test: 44 tests passed
xcodebuild TrackpadIOS Debug iPhone 17 simulator: BUILD SUCCEEDED
xcodebuild TrackpadIOS Debug connected iPad: BUILD SUCCEEDED
xcrun devicectl device install app connected iPad: installed `com.trackpad.ios`
xcrun devicectl device process launch connected iPad: launched `com.trackpad.ios`
```
