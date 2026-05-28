import CoreGraphics
import Darwin
import Foundation
import TrackpadKit

public struct MacInputInjector: Sendable {
    private let logger: any HostLogging
    private let displayBoundsProvider: @Sendable () -> [CGRect]

    public init(
        logger: any HostLogging = DisabledHostLogger(),
        displayBoundsProvider: (@Sendable () -> [CGRect])? = nil
    ) {
        self.logger = logger
        self.displayBoundsProvider = displayBoundsProvider ?? Self.activeDisplayBounds
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
        let next = nextPointerLocation(dx: dx, dy: dy)
        CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: next,
            mouseButton: .left
        )?.post(tap: .cghidEventTap)
    }

    private func dragPointer(button: PointerButton, dx: Double, dy: Double) {
        let next = nextPointerLocation(dx: dx, dy: dy)
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

    private func nextPointerLocation(dx: Double, dy: Double) -> CGPoint {
        PointerBoundsClamper.locationAfterApplyingDelta(
            current: currentPointerLocation(),
            dx: dx,
            dy: dy,
            displayBounds: displayBoundsProvider()
        )
    }

    private static func activeDisplayBounds() -> [CGRect] {
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        guard displayCount > 0 else {
            return []
        }

        var displays = Array(repeating: CGDirectDisplayID(), count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &displays, &displayCount)
        return displays.prefix(Int(displayCount)).map(CGDisplayBounds)
    }

    private func postSystemAction(_ action: SystemAction) {
        logger.info(category: "input", "systemAction action=\(action.rawValue)")
        switch action {
        case .missionControl:
            postExposeNotification(named: "com.apple.expose.awake")
        case .appExpose:
            postExposeNotification(named: "com.apple.expose.front.awake")
        case .previousSpace:
            postSpaceShortcut(action)
        case .nextSpace:
            postSpaceShortcut(action)
        }
    }

    private func postSpaceShortcut(_ action: SystemAction) {
        if postSpaceShortcutWithSystemEvents(action) {
            logger.info(category: "input", "systemEvents posted action=\(action.rawValue) keyCode=\(action.keyCode)")
            return
        }

        logger.warning(category: "input", "systemEvents failed action=\(action.rawValue) fallback=CGEvent")
        postKey(action.keyCode, flags: action.flags)
    }

    private func postSpaceShortcutWithSystemEvents(_ action: SystemAction) -> Bool {
        let source = """
        tell application "System Events"
            key code \(action.keyCode) using control down
        end tell
        """
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            logger.error(category: "input", "systemEvents scriptCreateFailed action=\(action.rawValue)")
            return false
        }

        script.executeAndReturnError(&error)
        if let error {
            logger.error(category: "input", "systemEvents error action=\(action.rawValue) error=\(error)")
            return false
        }

        return true
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
        let trusted = AccessibilityPermission.isTrusted
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        logger.info(
            category: "input",
            "key prepare keyCode=\(keyCode) flagsRaw=\(flags.rawValue) sourceNil=\(source == nil) keyDownNil=\(keyDown == nil) keyUpNil=\(keyUp == nil) trusted=\(trusted)"
        )
        keyDown?.flags = flags
        keyUp?.flags = flags
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        logger.info(category: "input", "key posted keyCode=\(keyCode) flagsRaw=\(flags.rawValue)")
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
