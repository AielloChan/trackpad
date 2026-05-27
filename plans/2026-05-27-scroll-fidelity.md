# Scroll Fidelity Implementation Plan

**Goal:** Improve two-finger scroll feel by carrying momentum semantics through the protocol, injecting macOS continuous scroll phases, and basing iOS momentum on recent scroll velocity.

**Architecture:** Keep platform-neutral scroll semantics in `TrackpadKit`. Keep iOS touch sampling in `TrackpadIOSCore` and macOS CGEvent details in `TrackpadHostCore`.

## Chunk 1: Protocol Momentum Semantics

- [x] Add failing protocol coding tests for optional scroll momentum phase.
- [x] Add optional `momentumPhase` to `ScrollEvent`.
- [x] Keep decoding old scroll payloads without `momentumPhase`.

## Chunk 2: macOS Scroll Injection

- [x] Add host mapper tests that preserve scroll phase and momentum phase.
- [x] Update `MacInputCommand.scroll` to include phases.
- [x] Set continuous scroll, scroll phase, and momentum phase fields in `MacInputInjector`.

## Chunk 3: iOS Velocity Momentum

- [x] Add failing tests for velocity-based scroll momentum planning.
- [x] Track recent scroll samples in `TouchSurfaceEventMapper`.
- [x] Start momentum from recent velocity instead of only the final delta.
- [x] Emit momentum scroll events with `momentumPhase`.

## Chunk 4: Verification

- [x] Run `TrackpadKit` tests.
- [x] Run `TrackpadIOSCore` tests.
- [x] Run `TrackpadHost` tests.
- [x] Build `TrackpadIOS`.
- [x] Build and relaunch `TrackpadHostApp`.
- [x] Update `TODOS.md` and `docs/ios-client-mvp.md`.

## Verification Result

```text
packages/TrackpadKit swift test: 14 tests passed
apps/ios/TrackpadIOSCore swift test: 24 tests passed
apps/macos/TrackpadHost swift test: 16 tests passed
xcodebuild TrackpadIOS Debug iPhone 17 simulator: BUILD SUCCEEDED
xcodebuild TrackpadHostApp Debug: BUILD SUCCEEDED
TrackpadHostApp relaunched from DerivedData, PID 89790
```
