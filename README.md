# Trackpad

[中文](README.zh-CN.md) | [Français](README.fr.md)

Trackpad is a native Apple-platform project that lets an iPhone or iPad act as a macOS trackpad. The repository is intended to live at:

```text
git@github.com:AielloChan/trackpad.git
```

The current milestone is a local-network MVP. The iOS app provides a black full-screen touch surface, captures multi-touch input, normalizes it into platform-neutral events, and sends those events to a macOS host app. The macOS host advertises itself over Bonjour, accepts a paired client connection, maps incoming events to macOS input commands, and injects pointer, click, drag, and scroll events through system APIs.

## Current Status

Phase 1 is functionally usable for local LAN testing:

- iOS/iPadOS client with a black touch surface.
- Bonjour discovery and manual IP connection fallback.
- Six-digit pairing gate before input is processed.
- Single-finger pointer movement.
- Single-finger tap for left click.
- Tap, quick second press, and movement for drag.
- Two-finger tap for right click.
- Two-finger scroll with first-pass momentum.
- Client-side latency, touch sample rate, and sent event rate display.
- Live tuning sliders for pointer speed, scroll momentum, and gesture timing.
- macOS host input injection for movement, click, drag, scroll phase, momentum phase, and double-click click state.
- Persistent macOS host logs at `~/Library/Logs/Trackpad/host.log`.

The goal is to keep improving the feel until it is as close as practical to the official Apple trackpad experience. Stage 1 still has manual verification items in `TODOS.md`, especially real-device gesture tuning and safe click/scroll checks.

## Repository Layout

```text
apps/
  ios/
    TrackpadIOS/          iOS/iPadOS app target.
    TrackpadIOSCore/      Reusable iOS gesture and client logic.
  macos/
    TrackpadHost/         macOS host Swift package and CLI.
    TrackpadHostApp/      Native macOS host app.

packages/
  TrackpadKit/            Shared protocol, transport, security, and platform-neutral models.

protocol/
  v1/                     Protocol documentation.

docs/
  architecture.md         System architecture.
  decisions/              Architecture decision records.
  ios-client-mvp.md       iOS MVP notes and verification history.
  macos-host-mvp.md       macOS host notes and verification history.

plans/
  *.md                    Implementation plans with progress tracking.

TODOS.md                  Current project tracker.
AGENTS.md                 Coding-agent instructions for this repository.
```

## Architecture

Trackpad is a two-sided control system:

```text
iPhone / iPad
  -> captures touches
  -> normalizes gestures
  -> sends TrackpadProtocol input events

macOS host
  -> receives session frames
  -> checks pairing
  -> maps events into macOS input commands
  -> injects CGEvent input
```

The shared protocol is the boundary between clients and hosts. iOS touch details should not leak into the macOS input layer, and macOS injection details should not leak into the iOS gesture mapper.

Transport is intentionally abstracted. The MVP uses Bonjour plus direct TCP on the local network. Future versions can add WebRTC-style NAT traversal, relay fallback, Android clients, and Windows hosts without changing the core input-event model.

## Requirements

- macOS with Xcode installed.
- Swift toolchain provided by Xcode.
- iPhone/iPad or iOS Simulator for the client.
- Accessibility permission granted to the running macOS host app or host CLI before input injection can work.

## Build and Run

### macOS Host App

Open and run:

```text
apps/macos/TrackpadHostApp/TrackpadHostApp.xcodeproj
```

Use the `TrackpadHostApp` scheme. The app shows the current pairing code, server state, port, connection count, and Accessibility permission state.

Command-line build:

```bash
xcodebuild -project apps/macos/TrackpadHostApp/TrackpadHostApp.xcodeproj -scheme TrackpadHostApp -configuration Debug build
```

### macOS Host CLI

```bash
cd apps/macos/TrackpadHost
swift run TrackpadHost status
swift run TrackpadHost request-permission
swift run TrackpadHost log-path
swift run TrackpadHost serve 123456
```

Local debug actions:

```bash
swift run TrackpadHost move-test
swift run TrackpadHost left-click-test
swift run TrackpadHost right-click-test
swift run TrackpadHost scroll-test
```

Run click and scroll debug actions only in a safe empty UI area.

### iOS Client

Open and run:

```text
apps/ios/TrackpadIOS/TrackpadIOS.xcodeproj
```

Use the `TrackpadIOS` scheme on a simulator or real device. A real iPhone or iPad is required for meaningful touch-feel testing.

Command-line simulator build example:

```bash
xcodebuild -project apps/ios/TrackpadIOS/TrackpadIOS.xcodeproj -scheme TrackpadIOS -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## Test

Run shared package tests:

```bash
cd packages/TrackpadKit
swift test
```

Run macOS host tests:

```bash
cd apps/macos/TrackpadHost
swift test
```

Run iOS core tests:

```bash
cd apps/ios/TrackpadIOSCore
swift test
```

## Roadmap

Near-term work:

- Finish real-device gesture tuning against Apple trackpad behavior.
- Replace JSON Lines with a compact binary input-event frame format when the event model stabilizes.
- Persist trusted devices and improve pairing UX.
- Add encrypted sessions.

Longer-term work:

- Remote connectivity with signaling, NAT traversal, and relay fallback.
- Android client.
- Windows host.
- Cross-platform protocol schema generation.

## Development Process

`TODOS.md` is the active progress source. `plans/*.md` are the implementation source for scoped work. Important architecture decisions belong in `docs/decisions/`.

Coding agents and contributors should read `AGENTS.md` before editing. The project favors small, readable files, reusable platform-neutral logic, and tests for protocol encoding, gesture state machines, event mapping, and transport behavior.
