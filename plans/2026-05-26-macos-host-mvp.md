# macOS Host MVP Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the macOS host side MVP so it can advertise on LAN, receive input events, map them to macOS input commands, and expose host state in the native macOS app.

**Architecture:** Keep platform-neutral event models in `TrackpadKit`, and keep macOS-specific hosting in `TrackpadHostCore`. The host app should depend on a small observable controller while injection, event parsing, and networking stay testable outside SwiftUI.

**Tech Stack:** Swift 6.2, Swift Package Manager, AppKit/SwiftUI, Network.framework, Bonjour/mDNS, CGEvent, XCTest/Swift Testing.

---

## Chunk 1: Testable Host Core

### Task 1: JSON Lines Event Framing

**Files:**
- Create: `apps/macos/TrackpadHost/Sources/TrackpadHostCore/Transport/InputEventLineCodec.swift`
- Create: `apps/macos/TrackpadHost/Tests/TrackpadHostCoreTests/InputEventLineCodecTests.swift`

- [x] **Step 1: Write failing tests**

Cover:

- encoding an `InputEvent` as one newline-terminated JSON frame.
- accepting partial data and returning no event until newline arrives.
- decoding multiple frames from one buffer.

- [x] **Step 2: Run failing tests**

Run: `cd apps/macos/TrackpadHost && swift test`

Expected: fail because `InputEventLineCodec` does not exist.

- [x] **Step 3: Implement codec**

Implement a small stateful decoder plus stateless encoder using `JSONEncoder` and `JSONDecoder`.

- [x] **Step 4: Run tests**

Run: `cd apps/macos/TrackpadHost && swift test`

Expected: pass.

### Task 2: Host Event Handling

**Files:**
- Create: `apps/macos/TrackpadHost/Sources/TrackpadHostCore/Input/MacInputPerforming.swift`
- Create: `apps/macos/TrackpadHost/Sources/TrackpadHostCore/Host/HostEventProcessor.swift`
- Create: `apps/macos/TrackpadHost/Tests/TrackpadHostCoreTests/HostEventProcessorTests.swift`

- [x] **Step 1: Write failing tests**

Cover:

- pointer move event is converted and performed once.
- tap event performs down and up commands.
- processor increments handled event count.

- [x] **Step 2: Run failing tests**

Run: `cd apps/macos/TrackpadHost && swift test`

Expected: fail because processor and protocol do not exist.

- [x] **Step 3: Implement performer protocol and processor**

Make `MacInputInjector` conform to `MacInputPerforming`.

- [x] **Step 4: Run tests**

Run: `cd apps/macos/TrackpadHost && swift test`

Expected: pass.

## Chunk 2: LAN Host

### Task 3: LAN Server

**Files:**
- Create: `apps/macos/TrackpadHost/Sources/TrackpadHostCore/Transport/LanHostServer.swift`
- Create: `apps/macos/TrackpadHost/Sources/TrackpadHostCore/Host/HostStatus.swift`

- [x] **Step 1: Implement Network.framework server**

Listen on TCP with Bonjour service `_trackpad-host._tcp`, accept connections, decode JSON Lines events, and pass events to a handler closure.

- [x] **Step 2: Add CLI serve command**

Modify `apps/macos/TrackpadHost/Sources/TrackpadHost/main.swift` with:

- `serve`
- `send-sample-event`

- [x] **Step 3: Verify with local command-line loop**

Run host in one process and send a sample event from another.

Expected: host logs accepted event and pointer movement is observable when Accessibility is granted.

### Task 4: macOS App Integration

**Files:**
- Create: `apps/macos/TrackpadHostApp/TrackpadHostApp/App/HostAppModel.swift`
- Modify: `apps/macos/TrackpadHostApp/TrackpadHostApp/UI/HostStatusView.swift`

- [x] **Step 1: Add app model**

Expose permission state, server state, port, connection count, handled event count, and start/stop actions.

- [x] **Step 2: Update UI**

Add start/stop server controls and compact status display.

- [x] **Step 3: Build app**

Run: `xcodebuild -project apps/macos/TrackpadHostApp/TrackpadHostApp.xcodeproj -scheme TrackpadHostApp -sdk macosx -configuration Debug CODE_SIGNING_ALLOWED=NO build`

Expected: build succeeds.

## Chunk 3: Verification and Docs

### Task 5: Documentation and Progress

**Files:**
- Modify: `TODOS.md`
- Create: `docs/macos-host-mvp.md`

- [x] **Step 1: Document host protocol**

Document TCP JSON Lines framing, Bonjour service name, and sample event payload.

- [x] **Step 2: Update progress**

Update `TODOS.md` with completed macOS host items and remaining safe manual checks.

- [x] **Step 3: Run full verification**

Run:

```bash
cd packages/TrackpadKit && swift test
cd apps/macos/TrackpadHost && swift test
xcodebuild -project apps/macos/TrackpadHostApp/TrackpadHostApp.xcodeproj -scheme TrackpadHostApp -sdk macosx -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Expected: all pass.

Observed local LAN loop: server handled one event and pointer coordinates changed from `579.8515625 -623.91015625` to `709.0625 882.64453125`.
