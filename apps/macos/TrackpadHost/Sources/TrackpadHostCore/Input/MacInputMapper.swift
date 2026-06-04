import AppKit
import TrackpadKit

public struct MacInputMapper: Sendable {
    private var pressedButtons: Set<PointerButton> = []
    private let systemGestureSettings: MacSystemGestureSettings

    public init(
        doubleClickIntervalSeconds: TimeInterval = NSEvent.doubleClickInterval,
        systemGestureSettings: MacSystemGestureSettings = .current()
    ) {
        _ = doubleClickIntervalSeconds
        self.systemGestureSettings = systemGestureSettings
    }

    public mutating func commands(for event: InputEvent) -> [MacInputCommand] {
        switch event.kind {
        case .pointerMove(let move):
            if pressedButtons.contains(.left) {
                return [.drag(button: .left, dx: move.dx, dy: move.dy)]
            }

            return [.move(dx: move.dx, dy: move.dy)]
        case .pointerButton(let button):
            updatePressedButtons(button)
            return [.button(button: button.button, phase: button.phase, clickCount: 1)]
        case .tap(let tap):
            return [
                .button(button: tap.button, phase: .down, clickCount: tap.clickCount),
                .button(button: tap.button, phase: .up, clickCount: tap.clickCount),
            ]
        case .scroll(let scroll):
            return [.scroll(dx: scroll.dx, dy: scroll.dy, phase: scroll.phase, momentumPhase: scroll.momentumPhase)]
        case .magnify(let magnify):
            return [.magnify(magnification: magnify.magnification, phase: magnify.phase)]
        case .systemAction(let systemAction):
            guard systemGestureSettings.allowsSystemAction(systemAction.action) else {
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
}
