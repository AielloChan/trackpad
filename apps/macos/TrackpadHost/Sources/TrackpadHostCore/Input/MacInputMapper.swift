import AppKit
import TrackpadKit

public struct MacInputMapper: Sendable {
    private struct LastTap: Sendable {
        var button: PointerButton
        var timestampNanos: UInt64
        var clickCount: Int
    }

    private var pressedButtons: Set<PointerButton> = []
    private var lastTap: LastTap?
    private let doubleClickIntervalNanos: UInt64
    private let systemGestureSettings: MacSystemGestureSettings

    public init(
        doubleClickIntervalSeconds: TimeInterval = NSEvent.doubleClickInterval,
        systemGestureSettings: MacSystemGestureSettings = .current()
    ) {
        self.doubleClickIntervalNanos = UInt64((max(doubleClickIntervalSeconds, 0) * 1_000_000_000).rounded())
        self.systemGestureSettings = systemGestureSettings
    }

    public mutating func commands(for event: InputEvent) -> [MacInputCommand] {
        switch event.kind {
        case .pointerMove(let move):
            lastTap = nil
            if pressedButtons.contains(.left) {
                return [.drag(button: .left, dx: move.dx, dy: move.dy)]
            }

            return [.move(dx: move.dx, dy: move.dy)]
        case .pointerButton(let button):
            lastTap = nil
            updatePressedButtons(button)
            return [.button(button: button.button, phase: button.phase, clickCount: 1)]
        case .tap(let tap):
            let clickCount = nextClickCount(for: tap.button, timestampNanos: event.timestampNanos)
            return [
                .button(button: tap.button, phase: .down, clickCount: clickCount),
                .button(button: tap.button, phase: .up, clickCount: clickCount),
            ]
        case .scroll(let scroll):
            lastTap = nil
            return [.scroll(dx: scroll.dx, dy: scroll.dy, phase: scroll.phase, momentumPhase: scroll.momentumPhase)]
        case .systemAction(let systemAction):
            lastTap = nil
            guard systemGestureSettings.allowsThreeFingerSystemAction(systemAction.action) else {
                return []
            }
            return [.systemAction(systemAction.action)]
        case .contact:
            return []
        }
    }

    private mutating func updatePressedButtons(_ button: PointerButtonEvent) {
        switch button.phase {
        case .down:
            pressedButtons.insert(button.button)
        case .up:
            pressedButtons.remove(button.button)
        }
    }

    private mutating func nextClickCount(for button: PointerButton, timestampNanos: UInt64) -> Int {
        let clickCount: Int
        if let lastTap,
           lastTap.button == button,
           timestampNanos >= lastTap.timestampNanos,
           timestampNanos - lastTap.timestampNanos <= doubleClickIntervalNanos {
            clickCount = min(lastTap.clickCount + 1, 3)
        } else {
            clickCount = 1
        }

        lastTap = LastTap(button: button, timestampNanos: timestampNanos, clickCount: clickCount)
        return clickCount
    }
}
