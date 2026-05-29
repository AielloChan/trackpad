# Gesture Glossary

This document defines the canonical gesture names for this repository. Use the `Canonical name` values in issues, plans, commits, and conversations so requests stay unambiguous.

Apple's current public trackpad gesture documentation groups gestures into point-and-click, scroll-and-zoom, and more-gestures settings. This project does not claim full Magic Trackpad parity yet; the support state below is the source of truth for this repository.

## Support States

| State | Meaning |
| --- | --- |
| `supported` | Implemented in the current iOS client and macOS host. |
| `partial` | Some behavior exists, but it is not equivalent to Apple's native trackpad behavior. |
| `planned` | Useful target for future work, not implemented yet. |
| `deferred` | Known Apple trackpad gesture, but not currently part of the near-term MVP. |

## Canonical Names

| Canonical name | Chinese alias | Apple-style gesture | Current effect | State |
| --- | --- | --- | --- | --- |
| `PointerMove` | 光标移动 | Move one finger on the surface. | Moves the macOS pointer. | `supported` |
| `LeftClickTap` | 左键轻点 | Tap with one finger. | Sends a left click after the tap-drag window expires. | `supported` |
| `DoubleClickTap` | 双击 | Two quick `LeftClickTap` gestures. | Host maps consecutive taps to native click counts for double-click selection/opening. | `supported` |
| `TapThenDrag` | 轻点后拖拽 | Tap, lift, quickly press again, then move. | Holds left mouse button and drags. | `supported` |
| `RightClickTap` | 右键轻点 | Click or tap with two fingers. | Sends a right click. | `supported` |
| `TwoFingerScroll` | 双指滚动 | Slide two fingers up, down, left, or right. | Sends finger-driven scroll deltas. | `supported` |
| `ScrollMomentum` | 滚动惯性 | Release after a two-finger scroll. | macOS host synthesizes inertial scrolling. | `partial` |
| `InterruptScrollMomentum` | 打断滚动惯性 | Touch the surface while momentum is active. | Cancels host-generated inertial scrolling immediately. | `supported` |
| `MissionControlSwipeUp` | Mission Control 上扫 | Swipe up with three or four fingers, depending on macOS settings. | Opens Mission Control when host settings allow it. | `supported` |
| `AppExposeSwipeDown` | App Expose 下扫 | Swipe down with three or four fingers, depending on macOS settings. | Opens App Expose when host settings allow it. | `supported` |
| `NextSpaceSwipeLeft` | 下一个 Space 左扫 | Swipe left with three or four fingers, depending on macOS settings. | Sends the equivalent of `Control-Right` to move to the next Space/full-screen app. | `supported` |
| `PreviousSpaceSwipeRight` | 上一个 Space 右扫 | Swipe right with three or four fingers, depending on macOS settings. | Sends the equivalent of `Control-Left` to move to the previous Space/full-screen app. | `supported` |
| `NotificationCenterEdgeSwipe` | 通知中心右边缘内扫 | Swipe left from the right edge with two fingers. | Opens Notification Center. The iOS implementation accepts any contact that starts near the right edge and requires two contacts before release. | `supported` |
| `NotificationCenterCloseSwipe` | 通知中心右扫关闭 | Swipe right with two fingers after Notification Center is open. | Closes Notification Center only after this client opened it with `NotificationCenterEdgeSwipe`. | `supported` |
| `LookUpDataDetectors` | 查询与数据检测 | Force click or three-finger tap, depending on settings. | Not implemented. | `planned` |
| `ForceClick` | 重按 | Press firmly on a Force Touch trackpad. | Not implemented; iPhone/iPad touch surfaces do not map cleanly to Force Touch. | `deferred` |
| `SmartZoom` | 智能缩放 | Double-tap with two fingers. | Not implemented. | `planned` |
| `PinchZoom` | 捏合缩放 | Pinch two fingers closed or spread them apart. | Not implemented. | `planned` |
| `Rotate` | 双指旋转 | Move two fingers around each other. | Not implemented. | `planned` |
| `SwipeBetweenPages` | 页面前进后退 | Swipe left or right with two fingers. | Not implemented. Must be disambiguated from horizontal scroll. | `planned` |
| `LaunchpadPinch` | Launchpad 捏合 | Pinch with thumb and three fingers. | Not implemented. | `deferred` |
| `ShowDesktopSpread` | 显示桌面展开 | Spread thumb and three fingers. | Not implemented. | `planned` |
| `ThreeFingerDrag` | 三指拖移 | Drag with three fingers when enabled in Accessibility settings. | Not implemented as an Apple-equivalent gesture. Current dragging uses `TapThenDrag`. | `deferred` |

## Current Gesture Rules

### `PointerMove`

- Starts with one contact.
- Sends relative pointer movement.
- Small startup moves are sent immediately with first-move limiting to avoid large first-frame jumps.

### `TapThenDrag`

- A one-finger tap is held briefly as a pending click so it can still become `TapThenDrag`.
- A completed one-finger tap followed by a second press inside the drag interval starts a drag.
- Default drag interval is `140 ms`.
- When the second press moves, the pending click is cancelled instead of being sent first. This keeps Mission Control from exiting before a window drag begins.
- Movement during the second press sends left-button down, pointer movement, then left-button up on release.

### `TwoFingerScroll`

- Starts with two contacts.
- Sends `scroll.began`, `scroll.changed`, and `scroll.ended`.
- If one finger is reported after a two-finger scroll has started, the mapper keeps the scroll ending path instead of converting the tail into a click or pointer move.
- The macOS host owns `ScrollMomentum`.

### `MissionControlSwipeUp`, `AppExposeSwipeDown`, `NextSpaceSwipeLeft`, `PreviousSpaceSwipeRight`

- The session begins when three contacts are down.
- If only one contact moves, the movement is treated as `PointerMove` so two stationary contacts can act as accidental touches.
- If two or more contacts move past the threshold, one system action is emitted.
- One touch session can emit only one three-finger system action. The session resets only after all contacts lift.
- macOS host settings gate these actions. If three-finger drag is enabled or the corresponding swipe setting is disabled, the host ignores the action.

### `NotificationCenterEdgeSwipe`

- Any contact in the current touch session may begin very close to the right edge of the iOS surface.
- The movement must be primarily inward, from right to left.
- At least two contacts must be present at some point before all contacts lift.
- The action is not gated by three-finger macOS settings.

### `NotificationCenterCloseSwipe`

- This gesture is armed only after this client emits `NotificationCenterEdgeSwipe` and all contacts lift.
- It starts with two contacts and requires a primarily rightward swipe.
- It is deliberately not global, so ordinary two-finger horizontal movement keeps mapping to `TwoFingerScroll` unless the Notification Center close context is armed.

## Naming Rules

- Use canonical names for bug reports and implementation requests, for example: `TwoFingerScroll has terminal reverse motion`.
- Use `Apple-style gesture` only when discussing desired parity with macOS settings or Apple documentation.
- If a request changes recognition thresholds or state-machine behavior, name the affected gesture and the exact phase: begin, move, release, or momentum.
- If a new gesture is added, update this file, `protocol/v1/wire-protocol.md` when protocol events change, and `TODOS.md`.
