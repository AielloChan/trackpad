# 0004: Public API Cable Path First

Date: 2026-05-27

## Context

The product should eventually prefer a physical cable connection when an iPhone or iPad is attached to the controlled Mac. A direct private USB data channel would be attractive for latency, but ordinary iOS apps do not have a general public API for arbitrary USB communication with a Mac app.

## Decision

Use public `Network.framework` path information as the first cable-aware transport foundation.

- Keep the current TCP session protocol unchanged.
- Prefer an initial wired-only TCP connection attempt using `NWParameters.requiredInterfaceType = .wiredEthernet`.
- Fall back to the default TCP path when the wired-only attempt is unavailable.
- Treat active `NWConnection` paths using `.wiredEthernet` as cable-like candidates.
- Display the active path on the iOS client so real devices can confirm whether USB attachment exposes a usable wired route.
- Defer live transport migration after a session is connected until the protocol has session resume and input-state handoff.

## Consequences

- The implementation remains App Store friendly and works with the existing LAN TCP transport.
- A USB cable will only be preferred if the system exposes a reachable IP path for the connection.
- Devices without a usable wired path pay a short initial fallback delay before using the default TCP path.
- Future private or developer-only transports can be explored behind a separate transport implementation, but they should not be the default product path.
