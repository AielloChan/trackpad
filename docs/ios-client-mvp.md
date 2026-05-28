# iOS Client MVP

The iOS client MVP is a native SwiftUI/UIKit app that sends single-finger movement events to the macOS host.

## Current Flow

1. Start the macOS host and note its pairing code.
2. Open the iOS app.
3. Tap `Scan QR` and scan the macOS host QR code, or select a discovered Bonjour host / enter IP details manually.
4. If using manual entry, enter the pairing code and tap Connect.
5. After connection succeeds, the app stores the trusted client key issued by the host for future reconnects.
6. Known hosts can reconnect with the stored key without requiring the current pairing code.
7. Single-finger movement sends `InputEvent.pointerMove` frames to macOS.
8. Single-finger tap, tap-then-quick-second-press drag, two-finger tap, and two-finger movement map to click, drag, right click, and scroll events.
9. Two-finger scroll release sends a clean scroll end; the macOS host synthesizes local inertial momentum.
10. The connected bar shows client-to-host round-trip latency and refreshes it once per second.
11. The connected bar also shows touch-move sample Hz and sent input-event Hz as `touch/send Hz`.
12. The connected bar shows the active connection path reported by `Network.framework`.
13. The connected bar stays narrow and status-only while connected; tuning controls live in the macOS host app.

## Transport

The iOS client uses Bonjour discovery plus a persistent TCP connection for the MVP. Manual IP and port entry remains available as a fallback.

On connect it sends:

```text
SessionFrame.clientHello
```

On touch movement it sends:

```text
SessionFrame.input(InputEvent.pointerMove)
```

On basic gestures it can also send:

```text
SessionFrame.input(InputEvent.tap)
SessionFrame.input(InputEvent.pointerButton)
SessionFrame.input(InputEvent.scroll)
```

For latency monitoring it sends:

```text
SessionFrame.ping(SessionPing)
```

The macOS host echoes:

```text
SessionFrame.pong(SessionPong)
```

When the macOS host sends `SessionFrame.hostLogRequest`, the iOS client uploads a bounded local diagnostic log with `SessionFrame.clientLogUpload`.

Frames are encoded with the shared `SessionFrameLineCodec` from `TrackpadKit`.

## Implementation Notes

- `TrackpadIOSCore` owns reusable touch mapping and session transport logic.
- The Xcode app references the reusable iOS core source files directly while the package remains the unit-test boundary.
- The Xcode app owns UI state and forwards platform-neutral `TouchContact` values into `TouchSurfaceEventMapper`.
- UIKit is responsible only for converting active `UITouch` instances into contact IDs and coordinates.
- Single-finger `touchesMoved` consumes UIKit coalesced touches and forwards each sample in order. Without this, `event.allTouches` only exposes the final delivered touch location and the first pointer event can contain several hardware samples' worth of accumulated movement.
- Bonjour discovery uses `_trackpad-host._tcp` and resolves the selected service with `NWConnection`.
- Manual IP entry remains intentional as a fallback.
- QR pairing uses AVFoundation to scan `trackpad://pair?...` payloads and then fills host, port, and pairing code before connecting.
- `NSCameraUsageDescription` is configured for QR pairing scans.
- After a successful short-code pairing, the host sends a `trustedClientKey` frame. The iOS client stores it in Application Support `trusted_hosts.jsonl` and sends it in future `clientHello` frames for the same host identity.
- The connected bar polls `TrackpadHostClient.measureLatency()` every second and displays RTT in milliseconds.
- The connected bar displays touch sampling and sent-event rates so stutter can be correlated with capture or transport behavior.
- The connected bar displays the active `NWConnection` path as `Path Wi-Fi`, `Path Wired`, `Path Cellular Expensive`, or an unavailable state.
- Wired paths are treated as cable-like candidates for future automatic transport preference. Direct arbitrary USB communication remains deferred because ordinary iOS apps do not have a general public USB data-channel API for Mac app control.
- `ClientDiagnosticLogStore` persists bounded local diagnostic lines and can build an upload payload when the host requests logs. High-frequency temporary touch and mapper diagnostics were removed after the pointer and drag startup jumps were verified fixed.
- High-frequency input events are enqueued into a single client send buffer. New frames are coalesced while a previous network send is in flight.
- The current Apple-platform TCP path uses no-delay TCP parameters to avoid small input packets waiting behind Nagle-style buffering.
- `TouchSurfaceEventMapper` ends an active two-finger gesture as soon as contact count drops below two so UIKit's staggered `touchesEnded` callbacks do not accidentally create a one-finger tap.
- After a two-finger scroll ends, `TouchSurfaceEventMapper` suppresses single-finger tap recognition for 80 ms to absorb staggered release callbacks without disabling normal pointer movement.
- `TouchGestureConfiguration` owns gesture timing thresholds. Defaults are tap duration `250 ms`, tap-then-second-press drag interval `140 ms`, and scroll-release tap guard `80 ms`.
- The connected bar is status-only after connection. It intentionally does not expose tuning sliders because the macOS host app owns the visible tuning controls.
- Tap-drag candidate detection no longer suppresses small pointer movement. The cursor moves immediately, and only crossing the drag threshold adds a left-button down event.
- The iOS app sends only finger-driven two-finger scroll input. The macOS host tracks recent scroll samples and synthesizes inertial momentum locally after `scroll.ended`.
- The iOS app sends a reliable `contact.began` boundary event on `touchesBegan`; the macOS host uses it to interrupt scheduled inertial scrolling as soon as a finger touches the surface again.
- Scroll momentum uses a host-side seed tracker that preserves the gesture's dominant axis, so final cross-axis jitter before release does not erase vertical or horizontal inertial scrolling.
- The iOS app receives low-frequency `configurationSync` frames for pointer, gesture, and scroll momentum tuning.
- `InputEventTuning` scales pointer movement on the iOS client before transport. The default pointer multiplier is `2.1x`; the visible tuning control lives in the macOS host app.
- Scroll momentum is synthesized on macOS with tunable amount, decay rate, and tail velocity window. Defaults are amount `5.0x`, decay `0.95`, and tail window `140 ms`; tuning ranges are amount `0...12x`, decay `0.72...0.995`, and tail window `30...500 ms`. The host normalizes momentum by frame interval so 120 Hz displays get more, smaller updates while preserving similar total distance.
- The macOS host edits the tuning settings; configuration sync applies changed snapshots on both endpoints without echoing identical values back.
- The macOS scroll injector marks scroll events as continuous, sets CoreGraphics scroll phase and momentum phase fields, and preserves subpixel residuals for integer wheel deltas.
- The macOS input mapper tracks pressed buttons and emits dragged mouse commands while the left button is held down, so host injection uses `leftMouseDragged` instead of `mouseMoved` during window drag.
- The macOS input mapper tracks consecutive tap events with the system double-click interval and injects CoreGraphics mouse events with the matching click state, so two quick iOS taps can trigger native macOS double-click selection.
- `NSLocalNetworkUsageDescription` and `NSBonjourServices` are configured for local TCP access and browsing.
- Debug simulator automation can be enabled with `TRACKPAD_AUTOCONNECT=1` for manual defaults, or `TRACKPAD_AUTOCONNECT_DISCOVERED=1` for Bonjour discovery. `TRACKPAD_SEND_SAMPLE_MOVE=1` sends one pointer move after connection.

## Current Limitations

- Pinch zoom, three-finger gestures, and four-finger system gestures are not implemented yet.
- One-finger hold-and-move is pointer movement, not drag.
- Drag currently starts when a single-finger tap is followed quickly by a second press and movement past the drag threshold; real-device timing tuning is still needed.
- Gesture timing settings are currently in-memory only and reset on app restart.
- Scroll momentum is a synthetic decay sequence from the macOS host with user-tunable amount, decay, and tail-window settings. It now supports longer inertial tails, but still needs real-device comparison against Magic Trackpad physics.
- Scroll phase and momentum fields are now injected on macOS, but native-trackpad parity still requires real-device tuning.
- Pointer speed and momentum settings are in-memory only and reset on app restart.
- The connection panel is shown while disconnected; the connected surface is black.
- The wire format is still JSON Lines. Binary framing is the next transport-efficiency milestone.
- Device trust persistence and encrypted sessions are still deferred.
- QR pairing currently supports the LAN TCP payload only and requires the QR host address to be reachable from the iPhone/iPad.
- Automatic transport migration to a cable-like path is deferred until the protocol supports session resume and input-state handoff.

## Verification Status

Verified:

```text
packages/TrackpadKit swift test
apps/ios/TrackpadIOSCore swift test
apps/macos/TrackpadHost swift test
xcodebuild -project apps/ios/TrackpadIOS/TrackpadIOS.xcodeproj -scheme TrackpadIOS -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -project apps/macos/TrackpadHostApp/TrackpadHostApp.xcodeproj -scheme TrackpadHostApp -configuration Debug build
xcodebuild -project apps/ios/TrackpadIOS/TrackpadIOS.xcodeproj -target TrackpadIOS -sdk iphonesimulator -arch arm64 -configuration Debug CODE_SIGNING_ALLOWED=NO build
xcrun simctl install booted apps/ios/TrackpadIOS/build/Debug-iphonesimulator/TrackpadIOS.app
SIMCTL_CHILD_TRACKPAD_AUTOCONNECT=1 SIMCTL_CHILD_TRACKPAD_SEND_SAMPLE_MOVE=1 xcrun simctl launch --terminate-running-process booted com.trackpad.ios
SIMCTL_CHILD_TRACKPAD_AUTOCONNECT_DISCOVERED=1 SIMCTL_CHILD_TRACKPAD_SEND_SAMPLE_MOVE=1 xcrun simctl launch --terminate-running-process booted com.trackpad.ios
```

Gesture mapper verification currently covers:

```text
single-finger tap -> left click
one-finger hold move -> pointer move only
single-finger tap, then second press within the drag interval and move -> left button down + pointer move + left button up
single-finger tap, then second press with movement below drag threshold -> pointer move only
single-finger tap, then second press after the default 140 ms drag interval and move -> pointer move only
custom tap-drag interval -> allows longer second-press delay when configured
two-finger tap -> right click
two-finger movement -> scroll began / changed / ended
two-finger scroll ending with one remaining contact -> scroll ended, no left click
single-finger tap within 80 ms after two-finger scroll release -> no left click
single-finger tap after the 80 ms suppression window -> left click
host scroll momentum synthesizer -> decaying changed steps plus final ended step
host scroll momentum synthesizer -> preserves vertical velocity after a final horizontal jitter sample
host scroll momentum synthesizer -> preserves horizontal velocity for intentional horizontal scroll
momentum scroll event -> scroll event with momentumPhase
left button down + pointer move on macOS host -> dragged mouse command
scroll with momentumPhase on macOS host -> scroll command preserving phase metadata
two tap events inside the macOS double-click interval -> second click uses clickCount 2
two tap events outside the macOS double-click interval -> clickCount resets to 1
```

The latest gesture polish verification also includes:

```text
apps/ios/TrackpadIOSCore swift test: 20 tests passed
apps/macos/TrackpadHost swift test: 15 tests passed
packages/TrackpadKit swift test: 12 tests passed
xcodebuild TrackpadIOS Debug iPhone 17 simulator: BUILD SUCCEEDED
xcodebuild TrackpadHostApp Debug: BUILD SUCCEEDED
TrackpadHostApp relaunched from DerivedData, PID 62652
```

The latest scroll fidelity verification also includes:

```text
apps/ios/TrackpadIOSCore swift test: 24 tests passed
apps/macos/TrackpadHost swift test: 16 tests passed
packages/TrackpadKit swift test: 14 tests passed
xcodebuild TrackpadIOS Debug iPhone 17 simulator: BUILD SUCCEEDED
xcodebuild TrackpadHostApp Debug: BUILD SUCCEEDED
TrackpadHostApp relaunched from DerivedData, PID 89790
```

The latest iOS tuning verification also includes:

```text
apps/ios/TrackpadIOSCore swift test: 27 tests passed
xcodebuild TrackpadIOS Debug iPhone 17 simulator: BUILD SUCCEEDED
```

The latest scroll tap suppression verification also includes:

```text
apps/ios/TrackpadIOSCore swift test: 29 tests passed
xcodebuild TrackpadIOS Debug iPhone 17 simulator: BUILD SUCCEEDED
```

The latest gesture timing tuning verification also includes:

```text
apps/ios/TrackpadIOSCore swift test: 31 tests passed
xcodebuild TrackpadIOS Debug iPhone 17 simulator: BUILD SUCCEEDED
```

The latest pointer small-move threshold verification also includes:

```text
apps/ios/TrackpadIOSCore swift test: 32 tests passed
xcodebuild TrackpadIOS Debug iPhone 17 simulator: BUILD SUCCEEDED
```

The latest momentum seed verification also includes:

```text
apps/ios/TrackpadIOSCore swift test: 34 tests passed
xcodebuild TrackpadIOS Debug iPhone 17 simulator: BUILD SUCCEEDED
```

The latest cable-path diagnostics verification also includes:

```text
apps/ios/TrackpadIOSCore swift test: 38 tests passed
xcodebuild TrackpadIOS Debug iPhone 17 simulator: BUILD SUCCEEDED
```

The latest macOS double-click state verification also includes:

```text
apps/macos/TrackpadHost swift test --filter MacInputMapperTests: 7 tests passed
apps/macos/TrackpadHost swift test: 18 tests passed
xcodebuild TrackpadHostApp Debug: BUILD SUCCEEDED
TrackpadHostApp relaunched from DerivedData, PID 53291
```

Observed macOS host status after simulator launch:

```text
Host status: running, port: 44787, connections: 1, authorized: 1, handled: 1
Host status: running, port: 44787, connections: 1, authorized: 1, handled: 2
```

The latest simulator build also includes:

```text
NSBonjourServices = ["_trackpad-host._tcp"]
```

Still open:

```text
xcodebuild -project apps/ios/TrackpadIOS/TrackpadIOS.xcodeproj -scheme TrackpadIOS -showdestinations
```

The installed Xcode still does not expose installed simulators for the scheme. The app can be built with a target-level simulator build, installed with `simctl`, and launched successfully.
