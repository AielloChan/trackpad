# TODOs

This file tracks active project progress. Keep it current whenever a task starts, completes, or changes scope.

## Current Phase: iOS Client MVP

- [x] Create initial repository documentation.
- [x] Create AI agent instructions.
- [x] Create initial implementation plan.
- [x] Create architecture and decision docs.
- [x] Create planned top-level directories.
- [x] Initialize `packages/TrackpadKit` as a Swift Package.
- [x] Define the first protocol models.
- [x] Initialize the macOS host spike as an Xcode-openable Swift Package executable.
- [x] Build the macOS host input-injection spike.
- [x] Create native iOS and macOS Xcode app projects.
- [x] Prepare macOS Accessibility permission prompt and CGEvent debug actions.
- [x] Manually verify macOS Accessibility permission and pointer CGEvent behavior after local authorization.
- [ ] Manually verify click and scroll CGEvent behavior in a safe UI area.
- [x] macOS host advertises a Bonjour TCP service.
- [x] macOS host receives JSON Lines input events over LAN.
- [x] macOS host maps received events into input injection.
- [x] macOS app exposes server start/stop and runtime status.
- [x] macOS host requires a pairing hello before processing input events.
- [x] macOS app displays a current pairing code.
- [x] Shared transport exposes reusable session JSON Lines encoding.
- [x] Create `TrackpadIOSCore` package for reusable iOS client logic.
- [x] iOS touch mapper converts single-finger movement into pointer move events.
- [x] Implement iOS app model, manual connection panel, and UIKit touch capture.
- [x] iOS app can manually connect to macOS host with IP, port, and pairing code.
- [x] iOS app sends single-finger movement events to macOS.
- [x] iOS app discovers macOS host over Bonjour and can connect to the discovered service.
- [x] iOS app maps single-finger tap to left click.
- [x] iOS app keeps one-finger hold-and-move as pointer movement.
- [x] iOS app maps tap-then-quick-second-press movement to left-button drag.
- [x] iOS app maps two-finger tap to right click.
- [x] iOS app maps two-finger movement to scroll events.
- [x] iOS app displays client-to-host latency in the connected bar and refreshes it once per second.
- [x] iOS app displays touch sample rate and sent input-event rate while connected.
- [x] iOS client coalesces high-frequency input frames through a single send buffer.
- [x] LAN TCP transport uses no-delay parameters for the current Apple-platform MVP.
- [x] macOS host injects live dragged mouse events while the left button is held down.
- [x] iOS two-finger scroll release no longer starts a one-finger tap state.
- [x] iOS two-finger scroll release sends a clean scroll-ended event without client-generated momentum.
- [x] Shared scroll protocol carries optional momentum phase for trackpad-like inertial scrolling.
- [x] macOS scroll injection sets continuous scroll, scroll phase, and momentum phase fields.
- [x] Disabled earlier iOS velocity-based scroll momentum after real-device jump reports.
- [x] iOS connected bar exposes pointer speed tuning.
- [x] iOS pointer speed tuning scales pointer movement events before transport.
- [x] Removed iOS scroll momentum amount tuning while momentum is disabled.
- [x] iOS suppresses accidental single-finger taps for 80 ms after two-finger scroll release.
- [x] iOS tap-then-second-press drag interval defaults to 140 ms after real-device tuning.
- [x] iOS pointer speed defaults to 2.1x after real-device tuning.
- [x] iOS connected bar exposes tap duration, drag interval, and scroll guard timing sliders.
- [x] iOS tap-drag candidate state no longer suppresses small pointer movements before the drag threshold.
- [x] macOS host maps consecutive tap events to click counts for double-click selection.
- [x] macOS injected button events set CoreGraphics mouse click state.
- [x] Removed iOS scroll momentum seed tracking while momentum is disabled.
- [x] macOS host writes persistent diagnostic logs for connection, pairing, input, and command mapping.
- [x] Generated Trackpad app icon is applied to both iOS and macOS app targets.
- [x] Shared QR pairing payload encodes LAN host, port, pairing code, and service name.
- [x] macOS host app displays a scannable QR pairing code.
- [x] iOS app scans a macOS pairing QR code and connects with the encoded host, port, and code.
- [x] iOS single-finger movement forwards coalesced touch samples to reduce apparent pointer jumps.
- [x] iOS client displays the active connection path so wired/cable-like routes are visible.
- [x] Add temporary `#########` diagnostics for the remaining one-finger pointer jump issue.
- [x] iOS single-finger mapper rebases the first accumulated movement sample to avoid a startup pointer jump.
- [x] macOS host can request connected iOS/iPadOS clients to upload local diagnostic logs.
- [x] Remove the initial movement dead zone from tap-then-quick-second-press drag.
- [x] Add targeted `#########` mapper diagnostics for the persistent tap-drag dead zone report.
- [x] Rebase large tap-drag first-move landing offsets after diagnosing the real-device jump.
- [x] iOS client attempts a wired-only TCP connection before falling back to the default path.
- [x] Replace high-frequency JSON input frames with compact HID-like binary input reports.
- [x] Document the detailed v1 wire protocol in `protocol/v1/wire-protocol.md`.
- [x] Diagnose two-finger scroll content jumping with targeted `#########` scroll logs.
- [x] Disable iOS-generated scroll momentum after real-device jumps continued.
- [x] Fix terminal reverse scroll when iOS reports one remaining touch before a two-finger end.
- [x] Implement three-finger swipe gestures for Mission Control, App Expose, and Spaces navigation.
- [x] Fix three-finger Space navigation to target the display under the current pointer instead of the first managed display.
- [x] Suppress accidental single-finger tap immediately after a three-finger system gesture.
- [x] Suppress residual reverse Space actions and two-finger taps immediately after a three-finger system gesture.
- [x] Map three-finger left/right Space navigation to `Control-Left` and `Control-Right` instead of direct managed Spaces switching.
- [x] Diagnose three-finger left/right Space navigation reaching macOS but failing on missing Automation permission.
- [x] Add macOS host Automation permission status and request path for `System Events`.
- [x] Clamp macOS pointer injection to active display bounds so edge movement does not accumulate offscreen debt.
- [x] Raise iOS pointer speed tuning upper bound to 10x.
- [x] Keep three-finger gesture sessions active until all touches lift, with one system action per session.
- [x] Preserve single-moving-contact pointer movement while three fingers are down.
- [ ] Manually verify two-finger scroll release no longer causes sudden inertial jumps on a real iPad.
- [ ] Manually verify two-finger scroll release no longer emits a terminal reverse scroll on a real iPad.

## Near-Term Milestones

- [x] macOS host app can request Accessibility permission.
- [x] macOS host app can move the pointer with a local debug action.
- [x] macOS host app has click and scroll local debug actions.
- [x] Shared protocol supports pointer move, button, tap, and scroll events.
- [x] LAN server receives a local test event and maps it to input injection.
- [x] iOS app displays a black full-screen touch surface.
- [x] iOS app sends single-finger movement events to macOS.
- [x] Bonjour discovery connects iOS to macOS on the same LAN.
- [x] Basic tap, drag, right-click, and scroll gestures are normalized on iOS.
- [x] Protocol-level ping/pong latency monitor is implemented over the MVP TCP session.
- [x] First-pass input stream optimization avoids one async task per touch-move callback.
- [x] Real-device gesture polish covers live drag injection and two-finger scroll end handling.
- [x] Protocol and macOS host still preserve optional momentum semantics for future redesign.
- [x] Three-finger swipe gestures trigger macOS system navigation actions.

## Verification Blockers

- [x] Grant Accessibility permission locally for `TrackpadHost` or `TrackpadHostApp`.
- [x] Re-run `swift run TrackpadHost status` from `apps/macos/TrackpadHost` and confirm it prints `Accessibility trusted: true`.
- [x] Run `swift run TrackpadHost move-test` from `apps/macos/TrackpadHost` and confirm the pointer moves.
- [x] Run `swift run TrackpadHost serve` and `swift run TrackpadHost send-sample-event` to verify LAN event injection.
- [ ] Run click and scroll debug actions only in a safe empty area.
- [x] Build `TrackpadIOS` for the booted simulator with command-line target build.
- [ ] Fix `TrackpadIOS` scheme destination discovery so `xcodebuild -showdestinations` lists installed simulators.
- [ ] Manually compare touch sample Hz, sent event Hz, RTT, and perceived pointer smoothness on a real device.
- [ ] Manually verify live window dragging and two-finger scroll release on a real iPhone/iPad.
- [ ] Redesign velocity-based momentum before comparing against native trackpad scrolling.
- [ ] Manually tune pointer speed on a real iPhone/iPad while connected to macOS.
- [ ] Manually verify two-finger scroll release no longer causes accidental left click on a real iPhone/iPad.
- [ ] Manually tune tap duration, drag interval, and scroll guard timing on a real iPhone/iPad.
- [ ] Manually verify double-tap on iOS selects text or triggers native macOS double-click behavior.
- [ ] Manually verify two-finger scroll release stops cleanly when the release contains small horizontal drift.
- [ ] Manually verify two-finger scroll release stops cleanly when iOS briefly reports one remaining touch before end.
- [ ] Manually verify QR pairing on a real iPhone/iPad camera against the macOS host QR code.
- [ ] Manually verify slow one-finger movement starts without a large first pointer jump on a real iPhone/iPad.
- [ ] Manually verify whether an iPhone/iPad connected by USB reports the active host connection as wired/cable-like.
- [x] Inspect reproduced one-finger pointer jump in macOS `#########` host logs.
- [ ] Manually verify host-triggered client log upload writes an iOS log file on macOS.
- [x] Manually verify three-finger swipe up/down/left/right on a real iPhone/iPad.
- [ ] Manually verify `TrackpadHostApp` Automation permission stays granted after restart and three-finger left/right changes Spaces.
- [ ] Manually verify pointer movement reverses immediately after pushing against a screen edge on a real iPhone/iPad.
- [ ] Manually verify one three-finger touch session cannot trigger a second system action until all touches lift.

## Deferred

- [ ] Persist trusted devices after QR or short-code pairing.
- [ ] Live transport migration to a lower-latency cable-like path after a session is already connected.
- [x] Report-level coalescing for pending pointer and scroll changed reports.
- [ ] Device key persistence and trust revocation.
- [ ] WebRTC DataChannel transport.
- [ ] STUN/TURN infrastructure.
- [ ] Coordinator service for remote device discovery.
- [ ] Relay fallback service.
- [ ] Android client.
- [ ] Windows host.
