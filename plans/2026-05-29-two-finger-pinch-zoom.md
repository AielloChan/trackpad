# Two-Finger Pinch Zoom

## Goal

Add `PinchZoom` support without leaking iOS touch details into macOS input injection. The client should recognize two-finger pinch/spread as a semantic magnify event, and the host should map that event to the best available macOS behavior.

## Scope

- Add a platform-neutral `MagnifyEvent` with magnification delta and phase.
- Encode/decode magnify events in the existing 32-byte HID-like `InputReport`.
- Recognize two-finger pinch/spread in the iOS touch mapper when contact-distance change dominates centroid movement.
- Keep ordinary two-finger pan behavior mapped to scroll.
- Coalesce droppable `magnify.changed` reports under send or host backlog pressure.
- Map macOS magnify commands through a first-pass cursor-located modified scroll fallback.
- Document the gesture, protocol fields, and manual verification status.

## Non-Goals

- Claim full native Magic Trackpad continuous magnification parity.
- Add private macOS event injection APIs.
- Add user-facing tuning controls for pinch thresholds before real-device feedback.

## Implementation Notes

- Positive magnification means two contacts spread apart.
- Negative magnification means two contacts pinch closed.
- Two-finger pan and pinch are mutually exclusive within one contact session. Once the mapper emits scroll or magnify for the current two-finger session, it keeps that mode until the two-finger session ends.
- Two-finger pan should lock to scroll when centroid movement matches or exceeds distance change.
- Pinch/spread should still lock to magnify when distance change clearly dominates centroid movement, even if both contacts include some same-direction drift.
- `TwoFingerScroll` has priority for ambiguous startup movement. Natural two-finger scrolls often include early contact spacing changes, so magnify requires a larger distance delta and stronger dominance before it can lock the session.
- `magnify.began` and `magnify.ended` are boundary events and should remain reliable.
- `magnify.changed` is realtime data and can be dropped or coalesced under backpressure.
- The macOS fallback accumulates magnification and emits bounded modified pixel-scroll deltas at the current cursor location so a single noisy report cannot flood the host.

## Progress

- [x] Add protocol and binary report tests.
- [x] Add iOS mapper tests for pinch in and pinch out.
- [x] Add macOS mapper and host processor tests.
- [x] Implement shared magnify protocol model.
- [x] Implement iOS two-finger pinch/spread recognition.
- [x] Keep same-direction two-finger pan locked to scroll instead of misclassifying distance jitter as magnify.
- [x] Allow drifted two-finger pinch/spread to classify as magnify when distance change strictly dominates centroid movement.
- [x] Make magnify startup conservative after logs showed intended scroll sessions being locked to `magnify`.
- [x] Implement macOS cursor-located modified scroll fallback injection.
- [x] Update gesture and protocol documentation.
- [ ] Manually verify `PinchZoom` on a real iPhone/iPad against Safari, Preview, and common document views.
- [ ] Evaluate whether a more native macOS continuous magnification path is practical with public APIs.
