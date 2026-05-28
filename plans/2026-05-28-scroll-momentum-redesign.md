# Scroll Momentum Redesign

**Goal:** Reintroduce two-finger inertial scrolling with a conservative macOS host-side axis-locked synthesizer that avoids the earlier sudden jump and terminal reverse-scroll bugs without sending synthetic momentum frames from iOS.

**Scope:**

- Track recent finger-driven scroll samples on macOS after they arrive from the iOS client.
- Build a stable host-side momentum seed from the average tail velocity over a tunable final sample window on the dominant recent axis.
- Ignore terminal cross-axis or reverse jitter when choosing the seed.
- Emit short decaying local macOS scroll commands with `momentumPhase`.
- Expose momentum amount, decay, and tail-window sliders in the macOS host app, then sync settings to the iOS client when needed.

## Tasks

- [x] Remove iOS-side scroll momentum event generation from the hot input path.
- [x] Add host-side scroll momentum seed tracking and step planning.
- [x] Schedule momentum steps from the macOS host after a finger scroll ends.
- [x] Add `scrollMomentumSettings` control frames for client-to-host tuning.
- [x] Add connected-bar momentum amount tuning.
- [x] Calculate tail velocity from the final 50 ms window instead of averaging the last few deltas.
- [x] Add connected-bar momentum decay-rate tuning.
- [x] Default the tail velocity window to 120 ms and expose live tail-window tuning.
- [x] Compact the connected-bar tuning controls into a two-column layout.
- [x] Add unit tests for host-side momentum generation and ignoring client momentum input.
- [x] Raise default host-side momentum to `5.0x`, decay to `0.95`, and tail sampling to `140 ms`.
- [x] Widen live tuning ranges to momentum `0...12x`, decay `0.72...0.995`, and tail window `30...500 ms`.
- [x] Increase host momentum command limits so high-decay tuning can produce a substantially longer inertial tail.
- [x] Normalize decay, stop threshold, and maximum step count by the host display frame interval so 120 Hz scrolling remains smooth without shortening total distance.
- [x] Preserve subpixel tail deltas in the CoreGraphics integer wheel fields with residual accumulation.

## Verification

- [x] Run `swift test` in `apps/macos/TrackpadHost`.
- [x] Run `swift test` in `apps/ios/TrackpadIOSCore`.
- [x] Run `swift test` in `packages/TrackpadKit`.
- [x] Build `TrackpadIOS` for iOS Simulator.
- [x] Build `TrackpadIOS` for generic iOS device.
- [ ] Build and install `TrackpadIOS` on a real iPad.
- [ ] Manually tune the default momentum amount on a real iPad.
- [ ] Manually verify no terminal reverse scroll occurs after a vertical two-finger scroll with small horizontal drift.
- [ ] Manually verify inertial scroll tail smoothness on a 60 Hz and a 120 Hz display.
