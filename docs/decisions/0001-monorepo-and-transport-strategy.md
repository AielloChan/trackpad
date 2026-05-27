# 0001: Monorepo and Transport Strategy

Date: 2026-05-26

## Status

Accepted

## Context

The product needs a native iOS/iPadOS input client and a macOS host agent. Future goals include Android clients, Windows hosts, and remote control across different networks.

The project should avoid coupling the input model to one platform or one transport. LAN mode is enough for the first MVP, but the architecture must leave room for P2P and relay transports.

## Decision

Use a monorepo:

- `apps/ios` for the native iOS/iPadOS client.
- `apps/macos` for the native macOS host.
- `packages/TrackpadKit` for shared Swift protocol, state, transport abstractions, and security primitives.
- `protocol/v1` for cross-platform protocol documentation and future schemas.
- `services/coordinator` and `services/relay` for future remote connectivity services.

Use a transport abstraction from the beginning:

- First implementation: LAN direct transport with Bonjour discovery.
- Future implementation: WebRTC DataChannel or comparable P2P transport.
- Fallback implementation: relay transport.

## Consequences

- First development should prioritize macOS input injection because it is the highest-risk area.
- Shared code must stay platform-neutral.
- The protocol must not assume iOS or macOS-specific types.
- Remote connectivity can be added without rewriting input semantics.

