# Protocol v1

This directory documents the cross-platform input protocol.

Detailed wire protocol specification: [wire-protocol.md](wire-protocol.md).

The first version should define semantic input events rather than raw platform-specific gestures:

- `pointer.move`
- `pointer.button`
- `pointer.tap`
- `scroll`
- `systemAction`
- `capabilities`
- `session`
- `session.ping`
- `session.pong`
- `hostLogRequest`
- `clientLogUpload`

`session.ping` / `session.pong` are protocol-level latency frames. The client sends a ping with a local timestamp and the host echoes it as a pong after pairing, allowing the client to calculate round-trip time without tying the feature to LAN, WebRTC, or relay transport details.

`hostLogRequest` / `clientLogUpload` are paired diagnostics frames. The host can ask an authorized client to upload a bounded local log payload, and the client replies on the same session without exposing platform-specific log storage paths in the protocol.

`scroll` events carry `dx`, `dy`, a required finger-scroll `phase`, and an optional `momentumPhase`. Normal finger movement leaves `momentumPhase` empty. Synthetic inertial scrolling sets it so host platforms can inject trackpad-like momentum events instead of plain mouse-wheel deltas.

`systemAction` events carry semantic desktop actions such as Mission Control, App Expose, previous Space, and next Space. Clients should send the semantic action rather than a macOS-specific keyboard shortcut so other host platforms can map the same intent to their own system APIs.

High-frequency input is carried as a fixed 32-byte binary `InputReport` frame:

```text
byte 0      magic 0xA7
byte 1      report version
byte 2      report kind
byte 3      flags / reserved
bytes 4-11  sequence number
bytes 12-19 timestamp nanos
bytes 20-23 dx fixed-point value
bytes 24-27 dy fixed-point value
byte 28     button / system action
byte 29     phase
byte 30     momentum phase
byte 31     reserved
```

The binary report is HID-like, not a system HID descriptor. It keeps the app-level semantic model compact while allowing pending movement and scroll deltas to be coalesced before transport send.

QR pairing uses a URL payload that is separate from the input stream:

```text
trackpad://pair?v=1&transport=lan-tcp&host=<host>&port=<port>&code=<code>&name=<serviceName>
```

For the current LAN MVP, the QR payload tells the mobile client which host and TCP port to connect to and which short pairing code to send in `SessionFrame.clientHello`. Future remote transports can add different `transport` values while keeping the same scanner entry point.

JSON Lines remains the control-message format for session frames. Binary reports are used for the hot input path.
