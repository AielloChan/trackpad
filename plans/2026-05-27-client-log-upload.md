# Client Log Upload Plan

**Goal:** Let the macOS host trigger a connected iOS/iPadOS client to upload local diagnostic logs back to the host for debugging.

**Status:** Implemented on 2026-05-27. Waiting for manual verification with an authorized real-device client.

## Scope

- Add protocol frames for host-initiated log requests and client log uploads.
- Persist iOS diagnostic lines locally instead of only printing to the Xcode console.
- Handle host log requests in the iOS client transport and upload a bounded log payload.
- Handle uploaded client logs in the macOS host and write them under the host log directory.
- Add a macOS host app button to request logs from authorized clients.

## Out of Scope

- Remote relay log collection.
- Account-based diagnostics.
- Binary compression or chunked large-file upload.
- Automatic upload without explicit host action.

## Verification

- [x] TrackpadKit protocol tests cover log request and upload frame round trips.
- [x] iOSCore tests cover log upload message building.
- [x] macOS host tests cover client log file writing.
- [x] macOS host LAN test covers host request, client upload response, and persisted log file.
- [x] Build iOS and macOS app targets.
- [x] Install and launch the latest iOS app on the connected iPad.
- [x] Relaunch the latest macOS host app.
- [ ] Manually connect a real iOS/iPadOS client, click `Request Client Logs`, and confirm a file appears under `~/Library/Logs/Trackpad/client-logs/`.

## Verification Result

```text
packages/TrackpadKit swift test: 20 tests passed
apps/ios/TrackpadIOSCore swift test: 43 tests passed
apps/macos/TrackpadHost swift test: 25 tests passed
xcodebuild TrackpadIOS Debug iPhone 17 simulator: BUILD SUCCEEDED
xcodebuild TrackpadHostApp Debug: BUILD SUCCEEDED
xcodebuild TrackpadIOS Debug connected iPad: BUILD SUCCEEDED
xcrun devicectl device install app connected iPad: installed `com.trackpad.ios`
xcrun devicectl device process launch connected iPad: launched `com.trackpad.ios`
TrackpadHostApp relaunched from DerivedData, PID 57744
```
