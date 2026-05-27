# QR Pairing Implementation Plan

**Goal:** Add QR-code pairing so the macOS host displays a scannable pairing payload and the iOS client can scan it to connect.

## Tasks

- [x] Add a platform-neutral QR pairing payload model to `TrackpadKit`.
- [x] Add macOS host IP selection and QR message generation.
- [x] Render the macOS pairing QR code in the host app.
- [x] Add iOS camera QR scanner UI.
- [x] Connect automatically from a scanned pairing QR payload.
- [x] Update docs and progress tracking.
- [x] Run package tests and app builds.

## Payload Format

QR content uses a small URL payload:

```text
trackpad://pair?v=1&transport=lan-tcp&host=<host>&port=<port>&code=<code>&name=<serviceName>
```

The payload stays transport-explicit so future remote/WebRTC pairing can add different `transport` values without changing the scanner entry point.

## Verification

- `packages/TrackpadKit swift test`: 18 tests passed.
- `apps/macos/TrackpadHost swift test`: 23 tests passed.
- `apps/ios/TrackpadIOSCore swift test`: 34 tests passed.
- `xcodebuild -project apps/macos/TrackpadHostApp/TrackpadHostApp.xcodeproj -scheme TrackpadHostApp -configuration Debug build`: succeeded.
- `xcodebuild -project apps/ios/TrackpadIOS/TrackpadIOS.xcodeproj -scheme TrackpadIOS -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' build`: succeeded.
- Real-device camera scan remains a manual verification item in `TODOS.md`.
