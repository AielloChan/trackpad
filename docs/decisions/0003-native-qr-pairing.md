# 0003 Native QR Pairing

## Status

Accepted

## Context

The project needs LAN pairing by QR code. The host must display a QR payload, and the iOS client must scan it to configure host, port, and pairing code.

## Decision

Use Apple native APIs for the first QR pairing implementation:

- macOS QR generation uses CoreImage `CIQRCodeGenerator`.
- iOS QR scanning uses AVFoundation metadata capture for QR codes.
- The shared payload format lives in `TrackpadKit` as `trackpad://pair?...`.

## Consequences

- No third-party dependency is required for QR pairing.
- The payload parser is reusable by future clients and hosts.
- The first QR payload is LAN-specific through `transport=lan-tcp`; future remote transports can add new transport values without changing the scanner entry point.
