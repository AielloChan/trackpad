# Protocol v1

This directory documents the cross-platform input protocol.

The first version should define semantic input events rather than raw platform-specific gestures:

- `pointer.move`
- `pointer.button`
- `pointer.tap`
- `scroll`
- `gesture`
- `capabilities`
- `session`
- `session.ping`
- `session.pong`

`session.ping` / `session.pong` are protocol-level latency frames. The client sends a ping with a local timestamp and the host echoes it as a pong after pairing, allowing the client to calculate round-trip time without tying the feature to LAN, WebRTC, or relay transport details.

`scroll` events carry `dx`, `dy`, a required finger-scroll `phase`, and an optional `momentumPhase`. Normal finger movement leaves `momentumPhase` empty. Synthetic inertial scrolling sets it so host platforms can inject trackpad-like momentum events instead of plain mouse-wheel deltas.

Early development can use Swift `Codable` models for speed. A future schema file, such as Protobuf or another compact binary schema, can be added after the model stabilizes and non-Apple platforms begin.
