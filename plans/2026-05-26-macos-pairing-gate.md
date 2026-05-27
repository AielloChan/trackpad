# macOS Pairing Gate Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a first security gate to the macOS host so input events are ignored until a client sends a valid pairing hello frame.

**Architecture:** Extend the shared protocol with session frames, keep pairing validation in macOS host core, and update the LAN server to track per-connection authorization before processing input events. This is not final cryptographic pairing; it is the first control boundary before iOS integration.

**Tech Stack:** Swift 6.2, Swift Package Manager, Network.framework, Swift Testing, SwiftUI.

---

## Chunk 1: Shared Session Protocol

### Task 1: Session Frame Model

**Files:**
- Create: `packages/TrackpadKit/Sources/TrackpadProtocol/SessionFrame.swift`
- Create: `packages/TrackpadKit/Tests/TrackpadKitTests/SessionFrameCodingTests.swift`

- [x] **Step 1: Write failing tests**

Cover client hello, input frame, and rejection frame JSON round trips.

- [x] **Step 2: Implement minimal session frame model**

Add `SessionFrame`, `ClientHello`, and `SessionRejected`.

- [x] **Step 3: Run tests**

Run `cd packages/TrackpadKit && swift test`.

## Chunk 2: Host Pairing Policy

### Task 2: Pairing Validation

**Files:**
- Create: `apps/macos/TrackpadHost/Sources/TrackpadHostCore/Security/PairingCode.swift`
- Create: `apps/macos/TrackpadHost/Sources/TrackpadHostCore/Security/PairingPolicy.swift`
- Create: `apps/macos/TrackpadHost/Tests/TrackpadHostCoreTests/PairingPolicyTests.swift`

- [x] **Step 1: Write failing tests**

Cover generated code shape, valid hello accepted, invalid hello rejected.

- [x] **Step 2: Implement pairing code and policy**

Use a six-digit numeric code for the MVP.

- [x] **Step 3: Run tests**

Run `cd apps/macos/TrackpadHost && swift test`.

## Chunk 3: Server Gate and UI

### Task 3: Gate LAN Server

**Files:**
- Modify: `apps/macos/TrackpadHost/Sources/TrackpadHostCore/Transport/InputEventLineCodec.swift`
- Modify: `apps/macos/TrackpadHost/Sources/TrackpadHostCore/Transport/InputEventClient.swift`
- Modify: `apps/macos/TrackpadHost/Sources/TrackpadHostCore/Transport/LanHostServer.swift`
- Modify: `apps/macos/TrackpadHost/Sources/TrackpadHost/main.swift`

- [x] **Step 1: Decode session frames**

Update line codec to encode/decode `SessionFrame`.

- [x] **Step 2: Require valid hello before input**

Track per-connection authorization and ignore/reject input before hello.

- [x] **Step 3: Update CLI**

`serve` displays pairing code; `send-sample-event` sends hello then input.

### Task 4: App Display

**Files:**
- Modify: `apps/macos/TrackpadHostApp/TrackpadHostApp/App/HostAppModel.swift`
- Modify: `apps/macos/TrackpadHostApp/TrackpadHostApp/UI/HostStatusView.swift`

- [x] **Step 1: Show pairing code**

Generate a pairing code in the app model and pass it to the server.

- [x] **Step 2: Rebuild app**

Run macOS app xcodebuild and verify success.

## Chunk 4: Verification

### Task 5: Final Checks

**Files:**
- Modify: `TODOS.md`
- Modify: `docs/macos-host-mvp.md`

- [x] **Step 1: Update docs and progress**

Document session hello and pairing code requirements.

- [x] **Step 2: Run full verification**

Run package tests, host tests, macOS app build, and local LAN sample.
