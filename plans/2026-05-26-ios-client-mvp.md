# iOS Client MVP Implementation Plan

> **For agentic workers:** Use TDD for reusable logic. Keep UI files small and keep networking, touch mapping, and view state separated.

**Goal:** Build the first iOS client loop: black touch surface sends paired single-finger pointer movement events to the macOS host over LAN.

**Architecture:** Add a reusable `TrackpadIOSCore` Swift Package for touch mapping and TCP session transport. Keep the Xcode app as a thin SwiftUI/UIKit shell that owns user-entered host settings and forwards touch deltas.

**Tech Stack:** Swift 6.2, Swift Package Manager, SwiftUI, UIKit touch handling, Network.framework.

---

## Chunk 1: Shared Line Encoding

### Task 1: Session Frame JSON Lines Codec

**Files:**
- Create: `packages/TrackpadKit/Sources/TrackpadTransport/SessionFrameLineCodec.swift`
- Create: `packages/TrackpadKit/Tests/TrackpadKitTests/SessionFrameLineCodecTests.swift`

- [x] **Step 1: Write failing tests**

Cover newline-terminated encoding, partial frame buffering, and multiple frames in one buffer.

- [x] **Step 2: Implement codec**

Expose a transport-neutral `SessionFrameLineCodec` from `TrackpadKit`.

- [x] **Step 3: Run tests**

Run `cd packages/TrackpadKit && swift test`.

## Chunk 2: iOS Core Package

### Task 2: Touch Mapping

**Files:**
- Create: `apps/ios/TrackpadIOSCore/Package.swift`
- Create: `apps/ios/TrackpadIOSCore/Sources/TrackpadIOSCore/Touch/TouchSurfaceEventMapper.swift`
- Create: `apps/ios/TrackpadIOSCore/Tests/TrackpadIOSCoreTests/TouchSurfaceEventMapperTests.swift`

- [x] **Step 1: Write failing tests**

Cover begin-without-event, move-to-pointer-delta, sequence increment, and reset after end.

- [x] **Step 2: Implement mapper**

Convert single touch position deltas into `InputEvent.pointerMove`.

### Task 3: Session Transport

**Files:**
- Create: `apps/ios/TrackpadIOSCore/Sources/TrackpadIOSCore/Transport/TrackpadConnectionConfiguration.swift`
- Create: `apps/ios/TrackpadIOSCore/Sources/TrackpadIOSCore/Transport/TrackpadSessionMessageBuilder.swift`
- Create: `apps/ios/TrackpadIOSCore/Sources/TrackpadIOSCore/Transport/TrackpadHostClient.swift`
- Create: `apps/ios/TrackpadIOSCore/Tests/TrackpadIOSCoreTests/TrackpadSessionMessageBuilderTests.swift`

- [x] **Step 1: Write failing tests**

Cover hello frame data and input frame data generated for a connection configuration.

- [x] **Step 2: Implement message builder and TCP client**

Use `Network.framework` for persistent TCP connection and shared `SessionFrameLineCodec` for session frames.

- [x] **Step 3: Run tests**

Run `cd apps/ios/TrackpadIOSCore && swift test`.

## Chunk 3: iOS App Integration

### Task 4: Black Touch Surface

**Files:**
- Modify: `apps/ios/TrackpadIOS/TrackpadIOS.xcodeproj/project.pbxproj`
- Modify: `apps/ios/TrackpadIOS/TrackpadIOS/UI/TouchSurface/TouchSurfaceView.swift`
- Create: `apps/ios/TrackpadIOS/TrackpadIOS/App/TrackpadClientModel.swift`
- Create: `apps/ios/TrackpadIOS/TrackpadIOS/UI/Connection/ConnectionPanelView.swift`
- Create: `apps/ios/TrackpadIOS/TrackpadIOS/UI/TouchSurface/TouchSurfaceRepresentable.swift`
- Create: `apps/ios/TrackpadIOS/TrackpadIOS/UI/TouchSurface/UIKitTouchSurfaceView.swift`

- [x] **Step 1: Add app model**

Own host, port, pairing code, connection state, and event sending.

- [x] **Step 2: Add UIKit touch capture**

Capture single-finger began/moved/ended and forward points to the model.

- [x] **Step 3: Add minimal connection overlay**

Show a compact dark connection panel while disconnected; keep the connected surface black.

- [x] **Step 4: Build iOS app**

Run simulator build with code signing disabled.

## Chunk 4: Verification

### Task 5: Final Checks

**Files:**
- Modify: `TODOS.md`
- Create: `docs/ios-client-mvp.md`

- [x] **Step 1: Update docs and progress**

Document manual connection flow and current limitations.

- [x] **Step 2: Run full verification**

Run shared package tests, iOS core tests, iOS simulator build, and existing macOS host tests.
