# Cable Path Diagnostics Plan

**Goal:** Add the first public-API-friendly foundation for USB/cable-preferred transport by exposing the active iOS-to-host connection path in the client UI.

**Architecture:** Keep the current LAN TCP protocol unchanged. Use `Network.framework` path information from the active `NWConnection` to classify the interface family. Treat `.wiredEthernet` as a cable-like candidate because Apple does not expose a general direct USB data channel for ordinary iOS apps.

**Status:** Completed on 2026-05-27.

## Chunk 1: Core Path Model

- [x] Add a reusable `NetworkPathSnapshot` model in `TrackpadIOSCore`.
- [x] Map `NWPath` into stable, testable path status and interface enums.
- [x] Add tests for label, cable candidate, and priority behavior.

## Chunk 2: Client Wiring

- [x] Publish active `NWConnection` path updates from `TrackpadHostClient`.
- [x] Surface the current path label from `TrackpadClientModel`.
- [x] Show the path in the connected bar next to latency and event rates.

## Chunk 3: Documentation and Verification

- [x] Document cable-path diagnostics and the limitation of direct USB transport.
- [x] Run iOS core tests.
- [x] Build the iOS app.
- [x] Update `TODOS.md`.

## Verification Result

```text
apps/ios/TrackpadIOSCore swift test: 38 tests passed
xcodebuild TrackpadIOS Debug iPhone 17 simulator: BUILD SUCCEEDED
```
