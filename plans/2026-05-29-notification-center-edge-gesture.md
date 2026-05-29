# Notification Center Edge Gesture

## Goal

Support the macOS Notification Center trackpad gesture from the iOS touch surface.

The intended behavior follows the macOS trackpad gesture shape: a leftward swipe starting from the right edge. To reduce accidental activation on the phone/tablet surface, recognition starts when any contact in the current touch session begins very close to the right edge. If two contacts are present at any point before all contacts lift and the edge contact passes the inward threshold, the client emits a semantic Notification Center system action.

## Scope

- Add a protocol-level `showNotificationCenter` system action.
- Encode/decode the action in compact binary input reports and JSON events.
- Detect the right-edge inward gesture in `TrackpadIOSCore`.
- Pass the iOS touch surface width into touch contacts so the mapper can test the right edge.
- Map the action on macOS independently of three-finger gesture settings.
- Trigger Notification Center from the macOS host app.
- Add a scoped two-finger right swipe close gesture after this client opens Notification Center.
- Document the v1 protocol addition and update project progress.

## Progress

- [x] Add failing protocol, iOS gesture, and macOS mapper tests.
- [x] Implement the shared system action and binary codec value.
- [x] Implement iOS right-edge gesture recognition.
- [x] Implement macOS action mapping and injection.
- [x] Update protocol and repository docs.
- [x] Run package tests and app builds.
- [x] Accept either first or later contacts as the right-edge candidate.
- [x] Add scoped two-finger right swipe close action after Notification Center open.

## Verification

- `cd packages/TrackpadKit && swift test`
- `cd apps/ios/TrackpadIOSCore && swift test`
- `cd apps/macos/TrackpadHost && swift test`
- Build `TrackpadIOS`.
- Build `TrackpadHostApp`.
- Manual: on a connected iPhone/iPad, start either finger very near the right edge, swipe left, ensure two fingers are present before lifting, and confirm macOS opens Notification Center.
- Manual: after opening Notification Center through the client, lift all fingers, then two-finger swipe right and confirm Notification Center closes.
