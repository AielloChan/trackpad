# Project Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Initialize the repository context and staged implementation path for a native iOS/iPadOS trackpad app and macOS host agent.

**Architecture:** Use a monorepo with native Apple apps under `apps/`, shared Swift code under `packages/TrackpadKit`, cross-platform protocol documentation under `protocol/v1`, and future remote networking services under `services/`. Keep the input protocol independent from transport and platform-specific input injection.

**Tech Stack:** Swift, Swift Package Manager, UIKit, SwiftUI, AppKit, Network.framework, Bonjour/mDNS, CGEvent, XCTest.

---

## Chunk 1: Repository Context

### Task 1: Documentation Bootstrap

**Files:**
- Create: `README.md`
- Create: `AGENTS.md`
- Create: `TODOS.md`
- Create: `docs/architecture.md`
- Create: `docs/decisions/0001-monorepo-and-transport-strategy.md`

- [x] **Step 1: Capture product and architecture summary**

Write `README.md` with the two-sided product model, local-first MVP, remote connectivity direction, and expected build order.

- [x] **Step 2: Capture AI agent instructions**

Write `AGENTS.md` with code quality rules, Swift conventions, architecture boundaries, testing expectations, logging rules, and the no-formatting rule.

- [x] **Step 3: Capture active progress**

Write `TODOS.md` with bootstrap completion and the next implementation milestones.

- [x] **Step 4: Capture architecture notes and first decision record**

Write `docs/architecture.md` and `docs/decisions/0001-monorepo-and-transport-strategy.md`.

### Task 2: Directory Skeleton

**Files:**
- Create: `apps/ios/.gitkeep`
- Create: `apps/macos/.gitkeep`
- Create: `packages/TrackpadKit/.gitkeep`
- Create: `protocol/v1/README.md`
- Create: `services/coordinator/.gitkeep`
- Create: `services/relay/.gitkeep`
- Create: `tools/.gitkeep`
- Create: `scripts/.gitkeep`

- [x] **Step 1: Create planned top-level directories**

Create the directories needed for Apple apps, shared code, protocol docs, future services, tools, and scripts.

- [x] **Step 2: Preserve empty directories**

Add `.gitkeep` files where a directory has no real content yet.

## Chunk 2: Next Implementation Plan

### Task 3: Swift Package Initialization

**Files:**
- Create: `packages/TrackpadKit/Package.swift`
- Create: `packages/TrackpadKit/Sources/TrackpadProtocol/`
- Create: `packages/TrackpadKit/Sources/TrackpadCore/`
- Create: `packages/TrackpadKit/Sources/TrackpadTransport/`
- Create: `packages/TrackpadKit/Sources/TrackpadSecurity/`
- Create: `packages/TrackpadKit/Tests/`

- [x] **Step 1: Create Swift Package**

Run: `cd packages/TrackpadKit && swift package init --type library`

Expected: SwiftPM package exists with default source and test targets.

- [x] **Step 2: Split package targets**

Modify `Package.swift` to define focused targets for protocol, core state, transport, and security.

- [x] **Step 3: Add first failing protocol tests**

Add tests for pointer move, button, tap, and scroll event encoding.

- [x] **Step 4: Implement minimal protocol models**

Add the minimum event types required by the macOS input-injection spike.

- [x] **Step 5: Run package tests**

Run: `cd packages/TrackpadKit && swift test`

Expected: all tests pass.

### Task 4: macOS Input-Injection Spike

**Files:**
- Create: `apps/macos/TrackpadHost/`
- Create: `apps/macos/TrackpadHost/Input/`
- Create: `apps/macos/TrackpadHost/Permissions/`

- [x] **Step 1: Create minimal macOS app project**

Create a macOS host spike target for the host agent. Current bootstrap uses an Xcode-openable Swift Package executable; native `.xcodeproj` app bundles remain a follow-up task.

- [x] **Step 2: Add permission status reader**

Implement a small type that reports Accessibility permission status.

- [x] **Step 3: Add local debug input actions**

Implement local debug actions for pointer move, left click, right click, and scroll.

- [ ] **Step 4: Verify manually on macOS**

Expected: after granting Accessibility permission, debug actions move/click/scroll the system pointer.

- [x] **Step 5: Record findings**

Update `TODOS.md` and add a decision record if macOS input behavior changes the architecture.

### Task 5: Native Xcode App Projects

**Files:**
- Create: `apps/ios/TrackpadIOS/TrackpadIOS.xcodeproj`
- Create: `apps/ios/TrackpadIOS/TrackpadIOS/App/TrackpadIOSApp.swift`
- Create: `apps/ios/TrackpadIOS/TrackpadIOS/UI/TouchSurface/TouchSurfaceView.swift`
- Create: `apps/macos/TrackpadHostApp/TrackpadHostApp.xcodeproj`
- Create: `apps/macos/TrackpadHostApp/TrackpadHostApp/App/TrackpadHostApp.swift`
- Create: `apps/macos/TrackpadHostApp/TrackpadHostApp/UI/HostStatusView.swift`

- [x] **Step 1: Create native iOS app project**

Create a minimal iOS SwiftUI app project with a black full-screen touch surface shell.

- [x] **Step 2: Create native macOS app project**

Create a minimal macOS SwiftUI app project that depends on `TrackpadHostCore` and exposes permission status UI.

- [x] **Step 3: Add shared schemes**

Create shared Xcode schemes so command-line and Xcode builds use stable scheme names.

- [x] **Step 4: Build native app projects**

Run:

```bash
xcodebuild -project apps/ios/TrackpadIOS/TrackpadIOS.xcodeproj -target TrackpadIOS -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
xcodebuild -project apps/macos/TrackpadHostApp/TrackpadHostApp.xcodeproj -scheme TrackpadHostApp -sdk macosx -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Expected: both builds succeed.

- [x] **Step 5: Complete manual macOS Accessibility pointer verification**

Run:

```bash
cd apps/macos/TrackpadHost
swift run TrackpadHost request-permission
swift run TrackpadHost status
swift run TrackpadHost move-test
```

Expected: after local Accessibility authorization, status prints `Accessibility trusted: true` and `move-test` moves the pointer.

Observed: `Accessibility trusted: true`; pointer location changed from `856.046875 -416.4609375` to `1245.125 -301.30078125` after `move-test`. Click and scroll remain separate safe-area manual checks.
