# Pointer Jump Diagnostics Plan

**Goal:** Add temporary `#########` diagnostics to locate why slow one-finger movement still appears to pause and then jump on the macOS cursor.

**Status:** Host diagnostics inspected on 2026-05-27. The first pointer event after touch begin can arrive with a much larger accumulated delta than following samples, so the iOS mapper now rebases that first large single-finger move instead of emitting it. Waiting for real-device verification before removing temporary diagnostics.

## Hypotheses Under Test

- UIKit may still deliver the first movement callback only after several hardware samples.
- Coalesced touch forwarding may be emitting historical samples too quickly in one run-loop pass, causing a visible compressed jump.
- The mapper may produce a large first delta because its previous point differs from UIKit's first delivered sample.
- The host may receive or map a large pointer delta even if the iOS client sampled smaller deltas.

## Diagnostic Points

- [x] Log touch begin, fallback move, and coalesced move samples in `UIKitTouchSurfaceView`.
- [x] Log mapper output and tuned send events in `TrackpadClientModel`.
- [x] Log host input events and mapped commands in `HostEventProcessor`.
- [x] Build iOS and macOS targets with diagnostics.
- [x] Inspect reproduced macOS host logs for first-event pointer deltas.

## Root Cause Evidence

The reproduced host log shows the first one-finger pointer event in a gesture carrying a large delta, followed by normal small deltas. Examples with the tuned 2.1x pointer speed included `dx=-15.75 dy=2.1`, `dx=-8.4 dy=1.05`, and `dx=-13.65 dy=3.15` as first emitted pointer moves, while subsequent moves were often around `dx=-1.05 dy=0`.

Because the large delta is present before host command mapping, the jump is not caused by macOS injection. The likely cause is UIKit delivering the first move after accumulating several hardware samples. `TouchSurfaceEventMapper` now drops and rebases only that first large single-finger move when it is not part of a tap-drag candidate. Small first moves still emit normally, and subsequent movement after the rebase emits regular deltas from the rebased touch point.

## Follow-Up

- [ ] Verify on a real iPhone/iPad that slow one-finger movement no longer starts with a visible jump.
- [ ] Remove temporary diagnostics after the root cause is confirmed and fixed.

## Verification Result

```text
apps/macos/TrackpadHost swift test: 23 tests passed
xcodebuild TrackpadIOS Debug iPhone 17 simulator: BUILD SUCCEEDED
xcodebuild TrackpadHostApp Debug: BUILD SUCCEEDED
TrackpadHostApp relaunched from DerivedData, PID 34947
apps/ios/TrackpadIOSCore swift test: 40 tests passed
xcodebuild TrackpadIOS Debug iPhone 17 simulator: BUILD SUCCEEDED
xcodebuild TrackpadIOS Debug connected iPad: BUILD SUCCEEDED
xcrun devicectl device install app connected iPad: installed `com.trackpad.ios`
xcrun devicectl device process launch connected iPad: launched `com.trackpad.ios`
```
