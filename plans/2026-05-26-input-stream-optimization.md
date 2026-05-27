# Input Stream Optimization Plan

**Goal:** Reduce visible pointer stutter before changing the wire protocol by removing avoidable per-event overhead and exposing the actual touch/send rates during connected sessions.

**Scope:** Keep the existing JSON Lines protocol for this pass. Do not introduce binary framing until the current event-rate and send-path behavior is observable.

## Chunk 1: Send Path

- [x] Add a tested input send buffer that drains one batch at a time.
- [x] Coalesce input frames while a previous send is still in flight.
- [x] Stop creating one Swift `Task` per touch-move callback.

## Chunk 2: Low-Latency TCP

- [x] Use TCP no-delay parameters for the iOS client connection.
- [x] Use TCP no-delay parameters for the macOS LAN listener.

## Chunk 3: Diagnostics

- [x] Track current touch-move sample rate on the iOS client.
- [x] Track current sent input-event rate on the iOS client.
- [x] Show rate diagnostics in the connected bar next to RTT.

## Chunk 4: Verification

- [x] Run `TrackpadIOSCore` tests.
- [x] Run `TrackpadHost` tests.
- [x] Run `TrackpadKit` tests.
- [x] Build `TrackpadIOS` simulator target.
- [x] Build `TrackpadHostApp`.
- [x] Update `TODOS.md` and `docs/ios-client-mvp.md`.

## Next Phase

- [ ] Design a compact binary frame for high-frequency pointer and scroll events.
- [ ] Keep JSON session frames for debuggability or provide a capability-negotiated fallback.
