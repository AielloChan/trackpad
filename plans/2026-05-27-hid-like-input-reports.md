# HID-like Input Reports

**Goal:** Reduce high-frequency input bandwidth and packet overhead by sending compact client-synthesized input reports instead of JSON input frames, while keeping JSON session frames for pairing, latency, QR, and diagnostics control messages.

**Architecture:**

- Keep `InputEvent` as the platform-neutral semantic model.
- Add a fixed-size binary input report wire format inspired by HID reports.
- Encode pointer, button, tap, and scroll reports into 32-byte frames.
- Keep existing JSON Lines session frames for low-frequency control traffic.
- Let the host stream codec accept both JSON Lines control frames and binary input reports on the same TCP connection.
- Coalesce adjacent pending pointer and scroll reports where ordering boundaries allow it.

## Tasks

- [x] Add failing TrackpadKit tests for binary input report encoding and mixed stream decoding.
- [x] Implement binary input report model and codec in `TrackpadKit`.
- [x] Switch the iOS high-frequency send path to binary report data.
- [x] Teach the macOS LAN host codec to decode binary input reports alongside JSON control frames.
- [x] Add report-level coalescing for pending pointer and scroll changed reports.
- [x] Update protocol docs, architecture notes, README, and `TODOS.md`.
- [x] Run shared, iOS core, and macOS host tests.

## Verification

- `packages/TrackpadKit swift test`: passed with 23 tests.
- `apps/ios/TrackpadIOSCore swift test`: passed with 47 tests.
- `apps/macos/TrackpadHost swift test`: passed with 26 tests.
- `xcodebuild -project apps/macos/TrackpadHostApp/TrackpadHostApp.xcodeproj -scheme TrackpadHostApp -configuration Debug build`: passed.
- `xcodebuild -project apps/ios/TrackpadIOS/TrackpadIOS.xcodeproj -scheme TrackpadIOS -configuration Debug -destination 'generic/platform=iOS Simulator' build`: passed.
