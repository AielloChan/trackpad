# 0005: HID-like Binary Input Reports

Date: 2026-05-27

## Status

Accepted

## Context

Pointer movement and scrolling are high-frequency inputs. Sending every input event as JSON Lines is easy to debug, but it adds avoidable encoding size, parsing work, and queued bytes when the client sampling rate increases.

USB and Bluetooth HID devices solve this class of problem with compact reports: the device sends a small report describing the current input state or delta, and intermediate reports can be coalesced when newer movement supersedes older movement.

## Decision

- Keep `InputEvent` as the platform-neutral semantic model inside the apps.
- Keep JSON Lines `SessionFrame` messages for pairing, latency, log upload, and other low-frequency control traffic.
- Encode high-frequency input events as fixed 32-byte binary `InputReport` frames.
- Allow the host stream codec to decode both JSON Lines control frames and binary input reports on the same connection.
- Coalesce adjacent pending pointer movement reports and adjacent compatible scroll changed reports on the iOS send path.

## Consequences

- Input bandwidth is substantially lower than JSON for pointer and scroll traffic.
- Control messages remain readable and easy to debug during the MVP.
- The current implementation is HID-like in report shape, but it is not a system-level virtual HID device.
- Future transports such as WebRTC DataChannel or relay can carry the same binary report frames without changing gesture mapping.
