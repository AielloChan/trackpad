# Trackpad Wire Protocol v1

This document describes the current Trackpad v1 wire protocol used between the mobile input client and the desktop host.

The protocol is intentionally split into two message families:

- JSON Lines `SessionFrame` control messages for low-frequency, human-readable session traffic.
- Fixed-size binary `InputReport` messages for high-frequency pointer, button, tap, and scroll input.

This is a HID-like application protocol. It borrows the compact report idea from HID, but it is not a USB HID descriptor, Bluetooth HID profile, DriverKit virtual HID device, or OS-level Magic Trackpad clone.

## Goals

- Keep touch capture platform-specific and host input injection platform-specific.
- Keep the wire protocol platform-neutral.
- Keep hot input messages compact enough to support higher sampling rates.
- Allow movement and scroll reports to be coalesced safely before transport send.
- Keep pairing, diagnostics, latency probing, and future session negotiation readable during MVP development.
- Preserve room for future transports such as WebRTC DataChannel, relay, or platform-specific local paths.

## Transport

The current Apple-platform MVP uses one ordered byte stream:

- Discovery: Bonjour service plus manual host/port entry.
- Connection: `Network.framework` TCP.
- TCP option: `noDelay = true`.
- Path preference: the iOS client first attempts a short wired-only TCP connection when the system exposes `.wiredEthernet`, then falls back to the default TCP path.

Future transports can carry the same byte stream semantics if they are reliable and ordered. If a future unordered transport is introduced, it must define separate reliability rules for button state, tap, and scroll phases.

## Session Flow

1. The host starts a TCP listener and advertises it over Bonjour.
2. The host generates a six-digit pairing code.
3. The mobile client connects to the host.
4. The client sends `SessionFrame.clientHello` as a JSON Lines control message.
5. The host validates the pairing code.
6. After validation, the host accepts input reports, ping frames, and diagnostics traffic from that connection.
7. If validation fails, the host rejects or closes the connection and ignores input.

```text
client                                           host
  |                                               |
  |--- JSON clientHello ------------------------->|
  |                                               | validate pairing code
  |--- binary InputReport ----------------------->| inject input
  |--- JSON ping -------------------------------->|
  |<-- JSON pong ---------------------------------|
  |<-- JSON hostLogRequest -----------------------|
  |--- JSON clientLogUpload --------------------->|
```

## Stream Framing

The receiver reads a continuous byte stream and decodes messages in order.

If the next byte is `0xA7`, the receiver treats the next 32 bytes as one binary `InputReport`.

If the next byte is anything else, the receiver reads until `\n` and decodes that line as one JSON `SessionFrame`.

Empty JSON lines are ignored.

```text
stream = *( input-report / json-line )

input-report = 32 bytes starting with 0xA7
json-line    = utf8-json "\n"
```

The current host also still accepts legacy JSON `SessionFrame.input` messages for tests and compatibility, but the current iOS hot input path sends binary reports.

## JSON Control Messages

JSON control messages are line-delimited UTF-8 JSON values encoded by Swift `Codable`.

Current Swift enum encoding wraps associated values under the case name and `_0`. Example:

```json
{"clientHello":{"_0":{"protocolVersion":1,"deviceId":"ios-device-1","deviceName":"iPad","pairingCode":"123456"}}}
```

Every JSON control message is terminated by one newline byte:

```text
0x7B ... 0x7D 0x0A
```

### `clientHello`

Sent by the client immediately after connecting.

| Field | Type | Meaning |
| --- | --- | --- |
| `protocolVersion` | `Int` | Protocol version. Current value is `1`. |
| `deviceId` | `String` | Client device identifier. Currently generated from the iOS vendor identifier when available. |
| `deviceName` | `String` | Human-readable client name. |
| `pairingCode` | `String` | Six-digit code shown by the host or encoded in QR pairing. |

### `ping`

Sent by the client to measure end-to-end round-trip latency.

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | `UInt64` | Client-generated probe id. |
| `clientSentNanos` | `UInt64` | Client monotonic send timestamp in nanoseconds. |

### `pong`

Sent by the host after receiving an authorized `ping`.

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | `UInt64` | Echoed ping id. |
| `clientSentNanos` | `UInt64` | Echoed client timestamp. |
| `hostReceivedNanos` | `UInt64` | Host receive timestamp in nanoseconds. |

### `rejected`

Sent or used by the host when a session cannot be accepted.

| Field | Type | Meaning |
| --- | --- | --- |
| `reason` | `String` | Human-readable rejection reason. |

### `hostLogRequest`

Sent by the host to ask an authorized client to upload a bounded local diagnostic log.

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | `String` | Request id, usually a UUID string. |
| `requestedAtNanos` | `UInt64` | Host request timestamp. |
| `reason` | `String` | Human-readable reason for the log request. |

### `clientLogUpload`

Sent by the client in response to `hostLogRequest`.

| Field | Type | Meaning |
| --- | --- | --- |
| `requestId` | `String` | Matching `hostLogRequest.id`. |
| `deviceId` | `String` | Uploading client device id. |
| `deviceName` | `String` | Uploading client name. |
| `createdAtNanos` | `UInt64` | Client timestamp when upload payload was created. |
| `content` | `String` | Bounded diagnostic log content. |
| `truncated` | `Bool` | Whether the client truncated older log content. |

### `input`

Legacy JSON input frame carrying an `InputEvent`.

Current production client input should use binary `InputReport` instead. Hosts may keep accepting JSON `input` during v1 for compatibility and tests.

## Binary InputReport

An `InputReport` is exactly 32 bytes.

All multi-byte integer fields are big-endian.

`dx` and `dy` are signed 32-bit fixed-point numbers with scale `256`. A wire value of `256` means `1.0`; a wire value of `-128` means `-0.5`.

Before encoding, `dx` and `dy` are rounded to the nearest fixed-point value and clamped to the signed 32-bit range.

| Offset | Size | Type | Field | Meaning |
| --- | ---: | --- | --- | --- |
| `0` | 1 | `UInt8` | magic | Always `0xA7`. |
| `1` | 1 | `UInt8` | version | Current binary report version. Always `1`. |
| `2` | 1 | `UInt8` | kind | Report kind. See kind table below. |
| `3` | 1 | `UInt8` | flags | Reserved. Current value is `0`. |
| `4` | 8 | `UInt64` | sequenceNumber | Monotonic client input sequence number. |
| `12` | 8 | `UInt64` | timestampNanos | Client event timestamp in nanoseconds. |
| `20` | 4 | `Int32` | dx | Fixed-point x delta. |
| `24` | 4 | `Int32` | dy | Fixed-point y delta. |
| `28` | 1 | `UInt8` | button | Pointer button code or `0`. |
| `29` | 1 | `UInt8` | phase | Button phase or scroll phase, depending on kind. |
| `30` | 1 | `UInt8` | momentumPhase | Scroll momentum phase or `0`. |
| `31` | 1 | `UInt8` | reserved | Reserved. Current value is `0`. |

### Report Kinds

| Value | Name | Used fields |
| ---: | --- | --- |
| `1` | `pointerMove` | `sequenceNumber`, `timestampNanos`, `dx`, `dy` |
| `2` | `pointerButton` | `sequenceNumber`, `timestampNanos`, `button`, `phase` |
| `3` | `tap` | `sequenceNumber`, `timestampNanos`, `button` |
| `4` | `scroll` | `sequenceNumber`, `timestampNanos`, `dx`, `dy`, `phase`, `momentumPhase` |

Unknown report kinds are invalid for v1 and should close or reject the stream.

### Pointer Buttons

| Value | Button |
| ---: | --- |
| `0` | none / unused |
| `1` | left |
| `2` | right |
| `3` | middle |

### Button Phases

Used by `pointerButton`.

| Value | Phase |
| ---: | --- |
| `0` | none / unused |
| `1` | down |
| `2` | up |

### Scroll Phases

Used by `scroll.phase` and `scroll.momentumPhase`.

| Value | Phase |
| ---: | --- |
| `0` | none / absent |
| `1` | began |
| `2` | changed |
| `3` | ended |

Normal finger scrolling sets `phase` and leaves `momentumPhase = 0`.

Synthetic inertial scrolling sets `momentumPhase` to the matching momentum phase, so the macOS host can inject continuous scroll events with momentum semantics.

## Input Semantics

### `pointerMove`

Represents relative pointer movement.

- `dx > 0` moves right.
- `dx < 0` moves left.
- `dy > 0` moves down in the current client coordinate system.
- `dy < 0` moves up in the current client coordinate system.

The host maps these deltas to platform pointer movement. If the host has a left button pressed, the same movement is mapped to drag.

### `pointerButton`

Represents an explicit pointer button state transition.

The current drag gesture uses:

```text
pointerButton(left, down)
pointerMove(...)
pointerMove(...)
pointerButton(left, up)
```

Button reports must not be dropped or coalesced across movement reports in a way that changes ordering.

### `tap`

Represents a complete click intent.

The macOS host converts a tap into a down/up pair. Consecutive taps inside the host double-click interval are mapped to increasing CoreGraphics click counts for native double-click behavior.

### `scroll`

Represents relative scroll movement.

Finger-driven scroll:

```text
scroll(dx, dy, phase=began, momentumPhase=none)
scroll(dx, dy, phase=changed, momentumPhase=none)
scroll(0, 0, phase=ended, momentumPhase=none)
```

Client-generated inertial scroll:

```text
scroll(dx, dy, phase=changed, momentumPhase=changed)
scroll(dx, dy, phase=changed, momentumPhase=changed)
scroll(0, 0, phase=ended, momentumPhase=ended)
```

## Coalescing Rules

The client may coalesce pending reports while a previous send operation is in flight.

Allowed:

- Adjacent `pointerMove` reports may be merged by summing `dx` and `dy`.
- Adjacent `scroll` reports may be merged when both reports have `phase = changed` and the same `momentumPhase`.

When reports are merged:

- The merged report keeps the newer `sequenceNumber`.
- The merged report keeps the newer `timestampNanos`.
- The merged report carries the summed deltas.

Not allowed:

- Do not coalesce across `pointerButton`.
- Do not coalesce across `tap`.
- Do not coalesce across scroll `began` or `ended`.
- Do not merge finger scroll and momentum scroll reports with different `momentumPhase`.

These rules preserve button ordering and scroll phase boundaries while reducing stale movement traffic.

## Error Handling

The receiver should treat these as protocol errors:

- Binary report length is not 32 bytes after `0xA7`.
- Magic byte is invalid for a binary report.
- Binary report version is unsupported.
- Binary report kind is unknown.
- Button, button phase, or scroll phase value is unsupported.
- JSON control line cannot be decoded as a supported `SessionFrame`.
- Input, ping, or diagnostic upload is received before a valid `clientHello`.

Current host behavior is conservative: decode failure records an error and closes/removes the connection.

## Versioning

There are two version fields:

- `ClientHello.protocolVersion`: session protocol version. Current value is `1`.
- `InputReport.version`: binary input report version. Current value is `1`.

Future binary report versions should either:

- use a new report version byte with negotiated support, or
- introduce new report kinds that older hosts reject cleanly.

Future session features should be introduced through `clientHello` capability fields or explicit capability messages before changing existing hot-path report semantics.

## QR Pairing Payload

QR pairing is outside the input stream. It is a URL payload scanned by the client:

```text
trackpad://pair?v=1&transport=lan-tcp&host=<host>&port=<port>&code=<code>&name=<serviceName>
```

| Query item | Meaning |
| --- | --- |
| `v` | QR payload version. Current value is `1`. |
| `transport` | Transport identifier. Current value is `lan-tcp`. |
| `host` | Host address for direct TCP connection. |
| `port` | TCP port. |
| `code` | Pairing code for `clientHello`. |
| `name` | Human-readable host service name. |

## Implementation Pointers

Current Swift implementation files:

- `packages/TrackpadKit/Sources/TrackpadProtocol/InputEvent.swift`
- `packages/TrackpadKit/Sources/TrackpadProtocol/InputReport.swift`
- `packages/TrackpadKit/Sources/TrackpadProtocol/SessionFrame.swift`
- `packages/TrackpadKit/Sources/TrackpadTransport/InputReportBinaryCodec.swift`
- `packages/TrackpadKit/Sources/TrackpadTransport/SessionFrameLineCodec.swift`
- `packages/TrackpadKit/Sources/TrackpadTransport/SessionStreamCodec.swift`
- `apps/ios/TrackpadIOSCore/Sources/TrackpadIOSCore/Transport/TrackpadHostClient.swift`
- `apps/macos/TrackpadHost/Sources/TrackpadHostCore/Transport/LanHostServer.swift`

Tests:

- `packages/TrackpadKit/Tests/TrackpadKitTests/InputReportBinaryCodecTests.swift`
- `apps/ios/TrackpadIOSCore/Tests/TrackpadIOSCoreTests/InputEventSendBufferTests.swift`
- `apps/macos/TrackpadHost/Tests/TrackpadHostCoreTests/LanHostServerTests.swift`
