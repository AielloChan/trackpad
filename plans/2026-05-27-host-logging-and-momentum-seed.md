# Host Logging and Momentum Seed Plan

**Goal:** Add persistent macOS host logs for future diagnosis, and keep scroll momentum from losing its intended axis when the last two-finger sample contains mostly cross-axis jitter.

**Root cause:** The macOS host does not currently cancel momentum because `dx` is non-zero. The iOS client starts momentum from `lastScrollVelocity`, and that value is overwritten by every scroll sample. If the final finger-driven sample before release is mostly horizontal jitter with a tiny vertical delta, the vertical momentum seed is replaced and the perceived vertical inertial scroll disappears.

## Chunk 1: Momentum Seed Tests

- [x] Add a failing core test showing vertical momentum survives a final horizontal jitter sample.
- [x] Add a test showing intentional horizontal scroll can still produce horizontal momentum.

## Chunk 2: Momentum Seed Implementation

- [x] Add reusable momentum seed tracking in `TrackpadIOSCore`.
- [x] Use the seed tracker from `TrackpadClientModel` instead of raw last scroll velocity.
- [x] Keep the protocol unchanged.

## Chunk 3: macOS Host Logging Tests

- [x] Add a failing file logger test that writes diagnostic lines to a chosen log file.
- [x] Add a host event processor test that input events and mapped commands are logged.

## Chunk 4: macOS Host Logging Implementation

- [x] Add a small file-backed host logger with a stable default log path.
- [x] Log host startup, shutdown, listener state, connection state, pairing result, input event summaries, mapped commands, and send errors.
- [x] Wire logging into both `TrackpadHostApp` and the CLI host.
- [x] Document where to find the log file.

## Chunk 5: Verification

- [x] Run `TrackpadIOSCore` tests.
- [x] Run `TrackpadHost` tests.
- [x] Build `TrackpadIOS`.
- [x] Build and relaunch `TrackpadHostApp`.
- [x] Update `TODOS.md` and MVP docs.

## Verification Results

```text
apps/ios/TrackpadIOSCore swift test: 34 tests passed
apps/macos/TrackpadHost swift test: 20 tests passed
xcodebuild TrackpadIOS Debug iPhone 17 simulator: BUILD SUCCEEDED
xcodebuild TrackpadHostApp Debug: BUILD SUCCEEDED
swift run TrackpadHost log-path: /Users/aiello/Library/Logs/Trackpad/host.log
TrackpadHostApp relaunched from DerivedData, PID 77018
tail /Users/aiello/Library/Logs/Trackpad/host.log: contains host app initialization and scroll input/command entries
```
