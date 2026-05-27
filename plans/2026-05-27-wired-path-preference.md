# Wired Path Preference Plan

**Goal:** Prefer a public-API cable-like TCP path when iOS/macOS expose one, while preserving the current LAN fallback.

**Status:** Implemented on 2026-05-27. Waiting for real-device USB path verification.

## Scope

- Keep the current TCP session protocol unchanged.
- Attempt a wired-only `NWConnection` first with a short timeout.
- Fall back to the existing default TCP path if wired-only connection is unavailable.
- Log connection attempts so real-device testing can show whether wired was attempted and selected.
- Do not implement private USB APIs or live session migration in this step.

## Tasks

- [x] Add a testable connection-attempt plan.
- [x] Use the plan in `TrackpadHostClient.connect`.
- [x] Log wired/default attempt start, success, and failure.
- [x] Run iOS core tests.
- [x] Build and install the iOS app on the connected iPad.

## Verification Result

```text
apps/ios/TrackpadIOSCore swift test: 46 tests passed
xcodebuild TrackpadIOS Debug iPhone 17 simulator: BUILD SUCCEEDED
xcodebuild TrackpadIOS Debug connected iPad: BUILD SUCCEEDED
xcrun devicectl device install app connected iPad: installed `com.trackpad.ios`
xcrun devicectl device process launch connected iPad: launched `com.trackpad.ios`
```
