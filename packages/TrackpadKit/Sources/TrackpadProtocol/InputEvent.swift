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
    case magnify(MagnifyEvent)
    case systemAction(SystemActionEvent)
    case contact(ContactEvent)
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
    public let clickCount: Int

    public init(button: PointerButton, clickCount: Int = 1) {
        self.button = button
        self.clickCount = min(max(clickCount, 1), 3)
    }

    private enum CodingKeys: String, CodingKey {
        case button
        case clickCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        button = try container.decode(PointerButton.self, forKey: .button)
        clickCount = min(max(try container.decodeIfPresent(Int.self, forKey: .clickCount) ?? 1, 1), 3)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(button, forKey: .button)
        if clickCount != 1 {
            try container.encode(clickCount, forKey: .clickCount)
        }
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

public struct MagnifyEvent: Codable, Equatable, Sendable {
    public let magnification: Double
    public let phase: ScrollPhase

    public init(magnification: Double, phase: ScrollPhase) {
        self.magnification = magnification
        self.phase = phase
    }
}

public struct SystemActionEvent: Codable, Equatable, Sendable {
    public let action: SystemAction

    public init(action: SystemAction) {
        self.action = action
    }
}

public struct ContactEvent: Codable, Equatable, Sendable {
    public let phase: ContactPhase
    public let contactCount: Int

    public init(phase: ContactPhase, contactCount: Int) {
        self.phase = phase
        self.contactCount = max(contactCount, 0)
    }
}

public enum SystemAction: String, Codable, Equatable, Sendable {
    case missionControl
    case appExpose
    case previousSpace
    case nextSpace
    case showNotificationCenter
    case hideNotificationCenter
    case openLaunchpad
    case closeLaunchpad
    case showDesktop
    case hideDesktop
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

public enum ContactPhase: String, Codable, Equatable, Sendable {
    case began
}
