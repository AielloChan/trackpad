# Architecture

Trackpad is a two-sided system. The iOS/iPadOS app is an input surface, while the macOS app is the host that receives events and injects system input.

## Core Principle

The protocol is the product boundary. Platform apps should convert local details into a platform-neutral event stream, and host apps should map that event stream into local system behavior.

```text
iOS touch
  -> gesture normalization
  -> TrackpadProtocol.InputEvent
  -> HID-like binary InputReport for high-frequency input
  -> Transport

macOS Transport
  -> JSON SessionFrame control messages or binary InputReport input messages
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

- Protocol models, including pointer, scroll, tap, and semantic system action events.
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
- System actions such as Mission Control, App Expose, and Spaces navigation.
- Capability negotiation.
- Sequence number and timestamp.

Raw touch streaming can be added later, but the first MVP should prefer semantic input events.

### Transport

The transport interface should support multiple implementations:

- LAN direct connection with Bonjour discovery.
- Public-API cable-like TCP paths when iOS and macOS expose a wired network route.
- Future WebRTC DataChannel transport for P2P remote control.
- Future relay transport for difficult NAT environments.

Business logic should depend on the transport interface, not a specific network implementation.

The current Apple-platform app first attempts a short wired-only TCP connection with `NWParameters.requiredInterfaceType = .wiredEthernet`, then falls back to the default TCP path. It also observes the active `NWConnection` path and treats `.wiredEthernet` as a cable-like candidate. Live transport migration after a session is already connected is deferred until the protocol supports session resume and input-state handoff.

The protocol is split into two logical channels over the current session stream. High-frequency pointer, button, tap, scroll, contact, and system action input uses a compact fixed-size binary report inspired by HID reports. Low-frequency control traffic uses JSON Lines for pairing, trusted-client key issuance, latency, diagnostics, and configuration sync so it remains easy to inspect. The macOS host accepts both message families on the same TCP stream after pairing.

Pointer movement and `scroll.changed` reports are treated as realtime, droppable data. The iOS client coalesces pending reports and drops stale realtime reports under send backpressure. The macOS host compacts decoded backlog batches before input injection. Boundary events such as button down/up, tap, contact, system action, `scroll.began`, and `scroll.ended` stay reliable and ordered.

Configuration sync uses full `TrackpadConfiguration` snapshots as a last-write-wins register for the MVP. Both endpoints keep a local copy, and the macOS host sends its current snapshot when a paired client connects. Applying a remote snapshot updates local consumers without echoing the same value back, which prevents sync loops. The macOS host app is the visible editing surface for tuning. Pointer speed and gesture thresholds are consumed by iOS, while scroll momentum is consumed by macOS.

The iOS client sends only finger-driven scroll input on the hot path. The macOS host generates two-finger scroll momentum locally after a finger-driven scroll ends, using an axis-locked decay sequence derived from the average tail velocity over a tunable final sample window. Momentum amount, decay rate, and tail velocity window are synchronized through the configuration channel; iOS does not enqueue synthetic momentum events over the network. The host normalizes momentum decay, stop threshold, and command limits by the active frame interval so higher-refresh displays receive more, smaller momentum updates without shortening the total inertial distance. The macOS scroll injector also carries subpixel residuals into CoreGraphics integer wheel fields so very small tail deltas are not lost. The tuning range is deliberately broad enough for real-device matching against native Apple trackpad inertial scroll distance. When any finger touches the iOS surface again, the client sends a `contact.began` boundary event so the host can cancel scheduled momentum immediately before visible pointer or scroll movement occurs.

Trusted-client reconnects are implemented as MVP trust-on-first-use persistence. A successful short-code pairing causes the host to generate a random client key, send it to the client, and store only its hash in `~/Library/Application Support/Trackpad/authorized_clients.jsonl` with device id, device name, first/last authorized timestamps, and first/last remote address. The iOS client stores the raw key in its Application Support `trusted_hosts.jsonl` and includes it in future `clientHello` frames for the same host identity. This removes repeated pairing-code entry for known devices, but it is not final cryptographic pairing; future secure pairing should move secrets into platform key storage and use challenge-response over an encrypted transport.

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
