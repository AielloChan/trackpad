# Four-Finger Launchpad Pinch

## Goal

Add `LaunchpadPinch`, matching Apple's thumb-and-three-fingers inward pinch at the semantic level, so the iOS client can ask the macOS host to open Launchpad.

Extend the same four-finger gesture family with Apple's spread shape for Show Desktop and with the tracked state transitions observed on native trackpads.

Apple public reference: https://support.apple.com/en-la/102482

## Scope

- Add a platform-neutral `openLaunchpad` system action.
- Encode `openLaunchpad` in the compact binary input report format.
- Recognize a four-contact inward pinch in `TrackpadIOSCore`.
- Map the action through the macOS host command layer.
- Open Launchpad from the macOS host app without depending on three-finger trackpad settings.
- Close Launchpad, show Desktop, and hide Desktop from the macOS host app.
- Track normal, Launchpad, and Desktop state locally in the iOS mapper for repeated gesture no-ops.
- Document the gesture and add focused tests.

## Progress

- [x] Add failing protocol, iOS gesture, and macOS mapper tests first.
- [x] Add `SystemAction.openLaunchpad` and binary report value `7`.
- [x] Add four-contact inward pinch recognition on iOS.
- [x] Add macOS host Launchpad execution through `/System/Applications/Launchpad.app`.
- [x] Keep the action independent from three-finger system gesture settings.
- [x] Add `closeLaunchpad`, `showDesktop`, and `hideDesktop` semantic system actions.
- [x] Add stateful four-finger pinch/spread transitions.
- [x] Update protocol docs, README files, gesture glossary, and TODO tracking.
- [x] Run package, iOS core, and macOS host tests.
- [ ] Manually verify `LaunchpadPinch` and `ShowDesktopSpread` on a real iPhone/iPad connected to the macOS host app.

## Recognition Notes

The iOS mapper compares each current contact's distance from the current centroid against its starting distance from the starting centroid. The gesture emits once when the average contraction and at least three inward-moving contacts cross their thresholds. Pure four-finger panning should not open Launchpad.

The state model is intentionally local and simple for the MVP:

- normal + inward pinch -> `openLaunchpad`, state becomes Launchpad
- Launchpad + inward pinch -> no-op
- Launchpad + outward spread -> `closeLaunchpad`, state becomes normal
- normal + outward spread -> `showDesktop`, state becomes Desktop
- Desktop + outward spread -> no-op
- Desktop + inward pinch -> `hideDesktop`, state becomes normal
