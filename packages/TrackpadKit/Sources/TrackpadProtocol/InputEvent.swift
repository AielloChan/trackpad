public struct InputEvent: Codable, Equatable, Sendable {
    public let version: Int
    public let sequenceNumber: UInt64
    public let timestampNanos: UInt64
    public let kind: InputEventKind

    public init(
        version: Int = 1,
        sequenceNumber: UInt64,
        timestampNanos: UInt64,
        kind: InputEventKind
    ) {
        self.version = version
        self.sequenceNumber = sequenceNumber
        self.timestampNanos = timestampNanos
        self.kind = kind
    }
}

public enum InputEventKind: Codable, Equatable, Sendable {
    case pointerMove(PointerMoveEvent)
    case pointerButton(PointerButtonEvent)
    case tap(TapEvent)
    case scroll(ScrollEvent)
    case systemAction(SystemActionEvent)
}

public struct PointerMoveEvent: Codable, Equatable, Sendable {
    public let dx: Double
    public let dy: Double

    public init(dx: Double, dy: Double) {
        self.dx = dx
        self.dy = dy
    }
}

public struct PointerButtonEvent: Codable, Equatable, Sendable {
    public let button: PointerButton
    public let phase: ButtonPhase

    public init(button: PointerButton, phase: ButtonPhase) {
        self.button = button
        self.phase = phase
    }
}

public struct TapEvent: Codable, Equatable, Sendable {
    public let button: PointerButton

    public init(button: PointerButton) {
        self.button = button
    }
}

public struct ScrollEvent: Codable, Equatable, Sendable {
    public let dx: Double
    public let dy: Double
    public let phase: ScrollPhase
    public let momentumPhase: ScrollPhase?

    public init(dx: Double, dy: Double, phase: ScrollPhase, momentumPhase: ScrollPhase? = nil) {
        self.dx = dx
        self.dy = dy
        self.phase = phase
        self.momentumPhase = momentumPhase
    }
}

public struct SystemActionEvent: Codable, Equatable, Sendable {
    public let action: SystemAction

    public init(action: SystemAction) {
        self.action = action
    }
}

public enum SystemAction: String, Codable, Equatable, Sendable {
    case missionControl
    case appExpose
    case previousSpace
    case nextSpace
}

public enum PointerButton: String, Codable, Equatable, Sendable {
    case left
    case right
    case middle
}

public enum ButtonPhase: String, Codable, Equatable, Sendable {
    case down
    case up
}

public enum ScrollPhase: String, Codable, Equatable, Sendable {
    case began
    case changed
    case ended
}
