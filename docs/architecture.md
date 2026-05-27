# Architecture

Trackpad is a two-sided system. The iOS/iPadOS app is an input surface, while the macOS app is the host that receives events and injects system input.

## Core Principle

The protocol is the product boundary. Platform apps should convert local details into a platform-neutral event stream, and host apps should map that event stream into local system behavior.

```text
iOS touch
  -> gesture normalization
  -> TrackpadProtocol.InputEvent
  -> Transport

macOS Transport
  -> TrackpadProtocol.SessionFrame
  -> pairing gate
  -> TrackpadProtocol.InputEvent
  -> input mapper
  -> CGEvent / system shortcuts
```

## Components

### iOS / iPadOS App

Responsibilities:

- Display a black full-screen touch surface.
- Capture multi-touch input.
- Normalize touches into pointer, scroll, tap, and gesture events.
- Discover trusted hosts.
- Maintain a low-latency connection to the selected host.

UIKit should be used for the touch surface because it offers direct multi-touch handling. SwiftUI can be used for settings, pairing, and device list UI.

### macOS Host Agent

Responsibilities:

- Advertise itself on the local network.
- Accept paired client connections.
- Receive and decode input events.
- Inject pointer, button, scroll, and keyboard shortcut actions.
- Guide users through Accessibility permission setup.
- Show connection state in a menu bar app or compact host UI.

The macOS host is the first implementation priority because input injection and permissions are the largest technical risks.

### TrackpadKit

Shared Swift package responsibilities:

- Protocol models.
- Session state.
- Transport interfaces.
- Discovery interfaces.
- Pairing and security primitives.
- Tests for platform-neutral logic.

TrackpadKit must not depend on UIKit, SwiftUI, or AppKit.

### Protocol

Version 1 should start with a minimal event model:

- Pointer move with `dx` and `dy`.
- Pointer button up/down.
- Tap with button intent.
- Scroll with `dx`, `dy`, and phase.
- Capability negotiation.
- Sequence number and timestamp.

Raw touch streaming can be added later, but the first MVP should prefer semantic input events.

### Transport

The transport interface should support multiple implementations:

- LAN direct connection with Bonjour discovery.
- Future WebRTC DataChannel transport for P2P remote control.
- Future relay transport for difficult NAT environments.

Business logic should depend on the transport interface, not a specific network implementation.

## Phases

### Phase 1: LAN MVP

- Shared protocol.
- macOS input injection.
- Bonjour discovery.
- Short-code pairing gate.
- Encrypted local connection after the event and session model stabilizes.
- iOS black touch surface.
- Single-finger movement, tap, right-click, and scroll.

### Phase 2: Secure Pairing and Better Gestures

- QR code or short-code pairing.
- Device identity and trust store.
- Revocation UI.
- Gesture configuration.
- Latency and connection diagnostics.

### Phase 3: Remote Mode

- Device account or device registry.
- Signaling service.
- WebRTC DataChannel or comparable P2P transport.
- TURN/relay fallback.
- Network quality probing and automatic transport selection.

### Phase 4: Additional Platforms

- Android client.
- Windows host.
- Shared protocol schema generation.
