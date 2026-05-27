# Client Latency Monitor Implementation Plan

**Goal:** Measure client-to-host connection latency once per second and show it at the top of the iOS connected surface.

**Architecture:** Add protocol-level `ping` / `pong` session frames so LAN, future P2P, and relay transports can share the same latency mechanism. The macOS host echoes pings after pairing; the iOS client measures RTT from sent timestamp to received pong.

## Chunk 1: Protocol

- [x] Add `SessionPing` and `SessionPong` frame models.
- [x] Add round-trip coding tests.

## Chunk 2: Host Echo

- [x] Add host test proving an authorized ping receives a matching pong.
- [x] Echo ping frames from authorized connections.

## Chunk 3: iOS Client

- [x] Add client receive loop and ping request API.
- [x] Update app model to poll latency every second while connected.
- [x] Show latency in the connected bar.

## Chunk 4: Verification

- [x] Run `TrackpadKit` tests.
- [x] Run `TrackpadHost` tests.
- [x] Run `TrackpadIOSCore` tests.
- [x] Build `TrackpadIOS` simulator target.
- [x] Update `TODOS.md` and `docs/ios-client-mvp.md`.
