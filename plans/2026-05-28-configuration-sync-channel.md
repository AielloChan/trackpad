# Configuration Sync Channel

**Goal:** Split the protocol into a high-frequency HID-like input channel and a low-frequency configuration sync channel. Configuration should be replicated on both client and host with last-write-wins semantics, initial sync on connection, and no echo loops when the received value is already current.

**Design:**

- Keep binary `InputReport` as the only high-frequency input channel.
- Add JSON `configurationSync` control frames for full configuration snapshots.
- Treat each configuration snapshot as an LWW register for this MVP: the last received or locally edited snapshot replaces the current snapshot when its value differs.
- Avoid sync loops by not emitting a new frame when applying a remote snapshot and by skipping sends when the snapshot is unchanged.
- Keep endpoint-specific consumption local: iOS consumes pointer speed and gesture thresholds; macOS consumes scroll momentum settings now and can consume more host-side settings later.

## Tasks

- [x] Add shared configuration snapshot and sync frame models in `TrackpadKit`.
- [x] Add iOS client send/receive support for configuration sync.
- [x] Add macOS host configuration storage, initial sync, and remote update handling.
- [x] Replace the ad hoc `scrollMomentumSettings` send path with full configuration sync.
- [x] Update docs and TODOs to describe logical channels and LWW config sync.
- [x] Move visible tuning controls to the macOS host app and keep the iOS connected bar status-only.

## Verification

- [x] Run `swift test` in `packages/TrackpadKit`.
- [x] Run `swift test` in `apps/ios/TrackpadIOSCore`.
- [x] Run `swift test` in `apps/macos/TrackpadHost`.
- [x] Build `TrackpadHostApp`.
- [x] Build `TrackpadIOS` for iOS Simulator.
