# Protocol v1

This directory documents the cross-platform input protocol.

Detailed wire protocol specification: [wire-protocol.md](wire-protocol.md).

The first version should define semantic input events rather than raw platform-specific gestures:

- `pointer.move`
- `pointer.button`
- `pointer.tap`
- `scroll`
- `contact`
- `systemAction`
- `capabilities`
- `session`
- `session.ping`
- `session.pong`
- `hostLogRequest`
- `clientLogUpload`
- `scrollMomentumSettings`
- `configurationSync`
- `trustedClientKey`

`session.ping` / `session.pong` are protocol-level latency frames. The client sends a ping with a local timestamp and the host echoes it as a pong after pairing, allowing the client to calculate round-trip time without tying the feature to LAN, WebRTC, or relay transport details.

`hostLogRequest` / `clientLogUpload` are paired diagnostics frames. The host can ask an authorized client to upload a bounded local log payload, and the client replies on the same session without exposing platform-specific log storage paths in the protocol.

`scroll` events carry `dx`, `dy`, a required finger-scroll `phase`, and an optional `momentumPhase`. Normal finger movement leaves `momentumPhase` empty. The current iOS client does not transmit synthetic momentum on the hot path; the macOS host synthesizes local momentum commands after finger scroll ends.

`configurationSync` is the low-frequency control frame for replicated settings. It carries a full `TrackpadConfiguration` snapshot containing pointer, gesture, and scroll momentum settings. Endpoints apply snapshots only when the value differs, so remote application does not echo the same configuration back.

`trustedClientKey` is sent by the host after a successful short-code pairing. The client stores the raw key locally and includes it in future `clientHello` frames. The host stores only a key hash in its JSONL authorized-client file and can auto-authorize matching future connections before checking the current short code.

`scrollMomentumSettings` is retained as a compatibility frame, but new clients should use `configurationSync`.

`systemAction` events carry semantic desktop actions such as Mission Control, App Expose, previous Space, next Space, show Notification Center, and hide Notification Center. Clients should send the semantic action rather than a macOS-specific keyboard shortcut so other host platforms can map the same intent to their own system APIs.

`contact` events are reliable boundary events emitted as soon as one or more fingers touch the mobile surface. Hosts do not inject visible input for them; the macOS host uses `contact.began` to immediately cancel locally generated inertial scrolling.

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
byte 28     button / system action / contact count
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
