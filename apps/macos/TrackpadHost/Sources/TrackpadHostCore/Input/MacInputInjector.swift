import CoreGraphics
import Darwin
import Foundation
import TrackpadKit

public struct MacInputInjector: Sendable {
    private let diagnostics: (@Sendable (String) -> Void)?

    public init(diagnostics: (@Sendable (String) -> Void)? = nil) {
        self.diagnostics = diagnostics
    }

    public func perform(_ command: MacInputCommand) {
        switch command {
        case .move(let dx, let dy):
            movePointer(dx: dx, dy: dy)
        case .drag(let button, let dx, let dy):
            dragPointer(button: button, dx: dx, dy: dy)
        case .button(let button, let phase, let clickCount):
            postButton(button, phase: phase, clickCount: clickCount)
        case .scroll(let dx, let dy, let phase, let momentumPhase):
            postScroll(dx: dx, dy: dy, phase: phase, momentumPhase: momentumPhase)
        case .systemAction(let action):
            postSystemAction(action)
        }
    }

    private func movePointer(dx: Double, dy: Double) {
        let current = currentPointerLocation()
        let next = CGPoint(x: current.x + dx, y: current.y + dy)
        CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: next,
            mouseButton: .left
        )?.post(tap: .cghidEventTap)
    }

    private func dragPointer(button: PointerButton, dx: Double, dy: Double) {
        let current = currentPointerLocation()
        let next = CGPoint(x: current.x + dx, y: current.y + dy)
        CGEvent(
            mouseEventSource: nil,
            mouseType: button.draggedEventType,
            mouseCursorPosition: next,
            mouseButton: button.cgMouseButton
        )?.post(tap: .cghidEventTap)
    }

    private func postButton(_ button: PointerButton, phase: ButtonPhase, clickCount: Int) {
        let cgButton = button.cgMouseButton
        let eventType = button.eventType(for: phase)

        let event = CGEvent(
            mouseEventSource: nil,
            mouseType: eventType,
            mouseCursorPosition: currentPointerLocation(),
            mouseButton: cgButton
        )
        event?.setIntegerValueField(.mouseEventClickState, value: Int64(max(clickCount, 1)))
        event?.post(tap: .cghidEventTap)
    }

    private func postScroll(dx: Double, dy: Double, phase: ScrollPhase, momentumPhase: ScrollPhase?) {
        let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: Int32(dy),
            wheel2: Int32(dx),
            wheel3: 0
        )
        event?.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        event?.setIntegerValueField(.scrollWheelEventScrollPhase, value: phase.cgScrollPhaseValue)
        event?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: momentumPhase?.cgScrollPhaseValue ?? 0)
        event?.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: dy)
        event?.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: dx)
        event?.post(tap: .cghidEventTap)
    }

    private func currentPointerLocation() -> CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    private func postSystemAction(_ action: SystemAction) {
        switch action {
        case .missionControl:
            postExposeNotification(named: "com.apple.expose.awake")
        case .appExpose:
            postExposeNotification(named: "com.apple.expose.front.awake")
        case .previousSpace:
            if !MacSpacesNavigator().move(.previous, diagnostics: diagnostics) {
                postKey(action.keyCode, flags: action.flags)
            }
        case .nextSpace:
            if !MacSpacesNavigator().move(.next, diagnostics: diagnostics) {
                postKey(action.keyCode, flags: action.flags)
            }
        }
    }

    private func postExposeNotification(named name: String) {
        if !CoreDockNotificationSender.post(name: name) {
            postDistributedNotification(named: name)
        }
    }

    private func postDistributedNotification(named name: String) {
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name(name),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    private func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyDown?.flags = flags
        keyUp?.flags = flags
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

private enum CoreDockNotificationSender {
    private typealias SendNotification = @convention(c) (CFString, Int32) -> Int32

    private static let function: SendNotification? = {
        let path = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/HIServices.framework/Versions/A/HIServices"
        guard let handle = dlopen(path, RTLD_LAZY),
              let symbol = dlsym(handle, "CoreDockSendNotification") else {
            return nil
        }

        return unsafeBitCast(symbol, to: SendNotification.self)
    }()

    static func post(name: String) -> Bool {
        guard let function else {
            return false
        }

        return function(name as CFString, 0) == 0
    }
}

private extension SystemAction {
    var keyCode: CGKeyCode {
        switch self {
        case .missionControl:
            return 126
        case .appExpose:
            return 125
        case .previousSpace:
            return 123
        case .nextSpace:
            return 124
        }
    }

    var flags: CGEventFlags {
        .maskControl
    }
}

private extension ScrollPhase {
    var cgScrollPhaseValue: Int64 {
        switch self {
        case .began:
            return 1
        case .changed:
            return 2
        case .ended:
            return 4
        }
    }
}

private extension PointerButton {
    var cgMouseButton: CGMouseButton {
        switch self {
        case .left:
            return .left
        case .right:
            return .right
        case .middle:
            return .center
        }
    }

    func eventType(for phase: ButtonPhase) -> CGEventType {
        switch (self, phase) {
        case (.left, .down):
            return .leftMouseDown
        case (.left, .up):
            return .leftMouseUp
        case (.right, .down):
            return .rightMouseDown
        case (.right, .up):
            return .rightMouseUp
        case (.middle, .down):
            return .otherMouseDown
        case (.middle, .up):
            return .otherMouseUp
        }
    }

    var draggedEventType: CGEventType {
        switch self {
        case .left:
            return .leftMouseDragged
        case .right:
            return .rightMouseDragged
        case .middle:
            return .otherMouseDragged
        }
    }
}
