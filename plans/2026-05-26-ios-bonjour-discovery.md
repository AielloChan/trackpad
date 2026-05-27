# iOS Bonjour Discovery Implementation Plan

> **For agentic workers:** Keep discovery independent from UI. A live `NWListener` / `NWBrowser` unit integration test was attempted, but `NWListener` service registration fails with `POSIXErrorCode(rawValue: 22)` in the Swift test/REPL context on this machine while the real host executable advertises correctly. Keep the stable model tests and verify live discovery through the macOS host plus simulator path.

**Goal:** Let the iOS client discover macOS hosts advertising `_trackpad-host._tcp` and select a discovered host instead of manually typing the address.

**Architecture:** Add Bonjour discovery primitives to `TrackpadIOSCore`, then expose discovered hosts in the iOS connection panel. Manual IP entry stays available as a fallback.

**Tech Stack:** Swift 6.2, Network.framework, Swift Testing, SwiftUI.

---

## Chunk 1: Discovery Core

### Task 1: Bonjour Browser

**Files:**
- Create: `apps/ios/TrackpadIOSCore/Sources/TrackpadIOSCore/Discovery/TrackpadHostAddress.swift`
- Create: `apps/ios/TrackpadIOSCore/Sources/TrackpadIOSCore/Discovery/DiscoveredTrackpadHost.swift`
- Create: `apps/ios/TrackpadIOSCore/Sources/TrackpadIOSCore/Discovery/BonjourTrackpadHostBrowser.swift`
- Create: `apps/ios/TrackpadIOSCore/Tests/TrackpadIOSCoreTests/TrackpadHostAddressTests.swift`

- [x] **Step 1: Write failing address/configuration tests**

Verify manual and Bonjour endpoints, discovered host identity, and Bonjour connection configuration behavior.

- [x] **Step 2: Implement discovery models and browser**

Expose discovered host name, service identity, and a connectable address.

- [x] **Step 3: Run iOS core tests**

Run `cd apps/ios/TrackpadIOSCore && swift test`.

## Chunk 2: Client Connection Address

### Task 2: Connect to Bonjour Service

**Files:**
- Modify: `apps/ios/TrackpadIOSCore/Sources/TrackpadIOSCore/Transport/TrackpadConnectionConfiguration.swift`
- Modify: `apps/ios/TrackpadIOSCore/Sources/TrackpadIOSCore/Transport/TrackpadHostClient.swift`
- Modify: `apps/ios/TrackpadIOSCore/Tests/TrackpadIOSCoreTests/TrackpadHostAddressTests.swift`

- [x] **Step 1: Support manual and Bonjour addresses**

Keep manual host/port behavior and add service endpoint behavior.

- [x] **Step 2: Run iOS core tests**

Run `cd apps/ios/TrackpadIOSCore && swift test`.

## Chunk 3: iOS UI Wiring

### Task 3: Discovery UI

**Files:**
- Modify: `apps/ios/TrackpadIOS/TrackpadIOS.xcodeproj/project.pbxproj`
- Modify: `apps/ios/TrackpadIOS/TrackpadIOS/App/TrackpadClientModel.swift`
- Modify: `apps/ios/TrackpadIOS/TrackpadIOS/UI/Connection/ConnectionPanelView.swift`
- Modify: `apps/ios/TrackpadIOS/TrackpadIOS/UI/TouchSurface/TouchSurfaceView.swift`

- [x] **Step 1: Start and stop browser from app model**

Update discovered hosts on the main actor.

- [x] **Step 2: Show discovered hosts**

Display compact buttons above the manual fields. Selecting one should fill the current target.

- [x] **Step 3: Add Bonjour Info.plist declaration**

Declare `_trackpad-host._tcp` for iOS local network browsing.

## Chunk 4: Verification

### Task 4: Final Checks

**Files:**
- Modify: `TODOS.md`
- Modify: `docs/ios-client-mvp.md`

- [x] **Step 1: Build and run tests**

Run TrackpadKit tests, iOS core tests, macOS host tests, and iOS simulator target build.

- [x] **Step 2: Verify simulator discovery path where possible**

Run the macOS host and confirm the iOS app can still connect and send one pointer move.

Result: with `TrackpadHost serve 123456` running, launching the simulator app with `TRACKPAD_AUTOCONNECT_DISCOVERED=1` and `TRACKPAD_SEND_SAMPLE_MOVE=1` connected through the Bonjour service and the host reported `authorized: 1, handled: 2` after the latest app build.
