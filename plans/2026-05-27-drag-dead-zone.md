# Drag Dead Zone Plan

**Goal:** Remove the initial movement dead zone when using tap-then-quick-second-press drag.

**Status:** Implemented on 2026-05-27. Follow-up refined on 2026-05-29 to reduce the remaining first-move dead zone while preserving landing-offset protection. A second 2026-05-29 log pass showed the startup landing offset can span multiple send batches, so drag startup limiting now carries state across batches. Waiting for real-device feel verification.

**Diagnostic Follow-up:** Real-device testing reported an initial drag dead zone, so temporary `######### ios.mapper` diagnostics were used for tap-drag candidate detection, first-move rebasing, drag button-down emission, and mapper event output. Those high-frequency diagnostics were removed after the fix was verified.

**Log Finding:** The reproduced drag sequence showed the second press was correctly detected as `candidate=true`, but the first move jumped from `x=302.5 y=795.5` to `x=313 y=792.5`. After pointer speed tuning this became the host's first drag delta `dx=22.05 dy=-6.3`, so the perceived dead zone was a large landing-offset jump, not delayed macOS injection.

**Second Log Finding:** The next reproduction showed the first emitted drag move was capped to `dx=-3 dy=3`, but the next send batch still carried the remaining landing-offset movement and pointer speed tuning expanded it to roughly `dx=-17.6 dy=7-13`. The host injected that second batch as a live drag, creating the remaining jump. The fix therefore keeps a small drag-startup limiter active for the first few pointer moves after left-button down, across send batches.

**Third Log Finding:** After cross-batch limiting, host logs still showed startup drag reports such as `dx=6` or `dx=7.2`. The root cause was the realtime send buffer coalescing multiple already-limited startup pointer reports while a send was in flight. The buffer now keeps the first drag startup pointer reports separate after left-button down, so each limited movement is delivered as its own small report.

**Normal Pointer Follow-up:** The same startup pattern affected ordinary single-finger pointer movement. The mapper used to drop the first large single-finger move to avoid a landing-offset jump; that produced a visible dead zone. Ordinary pointer startup now sends a small limited first movement immediately, keeps the first few startup moves capped after pointer-speed tuning, and prevents send-buffer coalescing from merging them into a larger first report.

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
- [x] Change large tap-drag first-move rebasing from dropping the first movement to sending a limited first movement immediately.
- [x] Add regression coverage for immediate limited movement on large tap-drag first moves.
- [x] Limit the first drag movement again after pointer speed tuning so high pointer speeds cannot reintroduce the jump.
- [x] Add temporary `######### ios.drag` diagnostics around raw mapper output and tuned send output.
- [x] Add stateful input tuning so the first tap-drag startup moves are limited across send batches.
- [x] Add send-buffer regression coverage that prevents drag startup pointer reports from being coalesced.
- [x] Add regression coverage for immediate limited ordinary pointer startup movement.
- [x] Add tuning and send-buffer regression coverage for ordinary pointer startup reports.

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

Follow-up verification after first-move limit refinement:

```text
apps/ios/TrackpadIOSCore swift test: 56 tests passed
xcodebuild TrackpadIOS Debug iPhone 17 simulator: BUILD SUCCEEDED
```

Second follow-up verification after post-tuning limit and diagnostics:

```text
apps/ios/TrackpadIOSCore swift test: 57 tests passed
xcodebuild TrackpadIOS Debug iPhone 17 simulator: BUILD SUCCEEDED
xcodebuild TrackpadIOS Debug connected iPhone: BUILD SUCCEEDED
xcrun devicectl device install app connected iPhone: installed `com.trackpad.ios`
xcrun devicectl device process launch connected iPhone: launched `com.trackpad.ios`
```

Third follow-up verification after cross-batch drag startup limiting:

```text
apps/ios/TrackpadIOSCore swift test: 58 tests passed
xcodebuild TrackpadIOS Debug connected iPhone: BUILD SUCCEEDED
xcrun devicectl device install app connected iPhone: installed `com.trackpad.ios`
xcrun devicectl device process launch connected iPhone: launched `com.trackpad.ios`
git diff --check: passed
```

Fourth follow-up verification after disabling drag-startup coalescing:

```text
apps/ios/TrackpadIOSCore swift test: 59 tests passed
xcodebuild TrackpadIOS Debug connected iPhone: BUILD SUCCEEDED
xcrun devicectl device install app connected iPhone: installed `com.trackpad.ios`
xcrun devicectl device process launch connected iPhone: launched `com.trackpad.ios`
```

Fifth follow-up verification after ordinary pointer startup limiting:

```text
apps/ios/TrackpadIOSCore swift test: 61 tests passed
xcodebuild TrackpadIOS Debug connected iPhone: BUILD SUCCEEDED
xcrun devicectl device install app connected iPhone: installed `com.trackpad.ios`
xcrun devicectl device process launch connected iPhone: launched `com.trackpad.ios`
```
