# Scroll Chaos Diagnostics

**Goal:** Locate why two-finger scrolling can make content move unpredictably after the binary report and report-coalescing changes.

**Current Hypotheses:**

- iOS mapper emits unexpected cross-axis or oversized scroll deltas from two-finger contact movement.
- Report-level coalescing merges too many `scroll.changed` reports into a large delta.
- Momentum starts from a bad seed velocity after finger release.
- macOS injection receives valid protocol data but maps phase/delta into CGEvent fields incorrectly.

## Tasks

- [x] Add temporary `#########` diagnostics for iOS scroll mapper output and momentum seed decisions.
- [x] Add temporary `#########` diagnostics for actual binary scroll report batches sent by the iOS transport.
- [x] Add temporary `#########` diagnostics for macOS host scroll input and command injection.
- [x] Rebuild/relaunch macOS host and rebuild/install iOS client for reproduction.
- [x] Inspect logs after reproduction and identify the root cause before fixing.
- [x] Add regression coverage for implausible terminal scroll velocity spikes.
- [x] Ignore implausible momentum seed velocity samples so a one-frame touch glitch cannot start a huge cross-axis momentum fling.
- [x] Diagnose the remaining terminal reverse scroll after momentum was disabled.
- [ ] Manually verify two-finger scrolling no longer causes content to run sideways.

## Verification

- Host logs showed normal scroll sequence `7342` with `dx=-65.75 dy=1.25`, followed by momentum sequence `7344` with `dx=-2102.47 dy=39.97`, proving that the chaos came from iOS momentum seed generation before macOS injection.
- Later host logs showed `momentum=none` and a repeated terminal `scroll.changed` reverse sample immediately before `scroll.ended`, proving the remaining reverse effect was independent of momentum.
- `swift test` passed in `apps/ios/TrackpadIOSCore` with 48 tests.
- `swift test` passed in `apps/macos/TrackpadHost` with 26 tests.
- macOS host and iOS real-device builds passed. iOS build still reports the existing orientation warning.
