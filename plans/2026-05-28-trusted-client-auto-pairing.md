# Trusted Client Auto Pairing

**Goal:** Persist previously paired clients so a known iPhone or iPad can reconnect without re-entering or re-scanning the short pairing code.

**Design:**

- Keep the existing six-digit pairing code as the first trust step.
- After a valid short-code pairing, generate a random client key and send it to the client over the paired session.
- Store only a hash of the client key on the macOS host in JSONL records under `authorized_clients.jsonl`.
- Store the raw client key on the iOS client in a local JSONL trusted-host record.
- On the next connection, the iOS client includes the stored key in `clientHello`; the host accepts it before checking the short code.
- Keep this as an MVP trust-on-first-use mechanism, not a replacement for future encrypted pairing and device identity.

## Tasks

- [x] Extend the session protocol with optional trusted-client key fields.
- [x] Add macOS JSONL authorized-client storage and key validation.
- [x] Persist a generated trusted-client key after successful short-code pairing.
- [x] Add iOS JSONL trusted-host storage and send the stored key in future `clientHello` frames.
- [x] Update protocol and architecture docs.
- [x] Verify with unit tests, package tests, and app builds.

## Verification

- [x] Run `swift test` in `packages/TrackpadKit`.
- [x] Run `swift test` in `apps/ios/TrackpadIOSCore`.
- [x] Run `swift test` in `apps/macos/TrackpadHost`.
- [x] Build `TrackpadHostApp`.
- [x] Build `TrackpadIOS` for iOS Simulator.
- [ ] Manually verify reconnecting a known real iPhone/iPad can skip the current pairing code.
