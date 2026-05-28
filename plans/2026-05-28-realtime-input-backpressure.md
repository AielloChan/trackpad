# Realtime Input Backpressure

**Goal:** Avoid delayed pointer and scroll backlog execution when network latency or host CPU load causes input messages to accumulate.

**Scope:**

- Treat pointer movement and `scroll.changed` as realtime droppable reports.
- Preserve reliable ordering for button, tap, system action, `scroll.began`, and `scroll.ended`.
- Keep the current TCP session and binary report protocol unchanged.

## Tasks

- [x] Raise iOS and macOS input transport queues to user-interactive QoS.
- [x] Add iOS pending send-buffer stale report dropping for pointer and `scroll.changed` reports.
- [x] Add iOS pending send-buffer maximum backlog trimming for droppable reports.
- [x] Add macOS receive-batch compaction for decoded pointer and `scroll.changed` backlog.
- [x] Add tests for client stale dropping and host receive-batch compaction.

## Verification

- `swift test` passed in `apps/ios/TrackpadIOSCore`.
- `swift test` passed in `apps/macos/TrackpadHost`.
- `git diff --check` passed.

## Manual Verification

- Compare pointer smoothness under high host CPU load before and after this change.
- Confirm drag button down/up is not lost when pointer movement is dropped or compacted.
- Confirm two-finger scroll still sends a clean `scroll.ended` after stale `scroll.changed` reports are dropped.
