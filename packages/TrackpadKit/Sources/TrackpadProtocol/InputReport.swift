import Foundation

public struct InputReport: Equatable, Sendable {
    public let sequenceNumber: UInt64
    public let timestampNanos: UInt64
    public let kind: InputReportKind

    public init(sequenceNumber: UInt64, timestampNanos: UInt64, kind: InputReportKind) {
        self.sequenceNumber = sequenceNumber
        self.timestampNanos = timestampNanos
        self.kind = kind
    }

    public init(event: InputEvent) throws {
        self.sequenceNumber = event.sequenceNumber
        self.timestampNanos = event.timestampNanos
        switch event.kind {
        case .pointerMove(let move):
            self.kind = .pointerMove(dx: move.dx, dy: move.dy)
        case .pointerButton(let button):
            self.kind = .pointerButton(button: button.button, phase: button.phase)
        case .tap(let tap):
            self.kind = .tap(button: tap.button)
        case .scroll(let scroll):
            self.kind = .scroll(
                dx: scroll.dx,
                dy: scroll.dy,
                phase: scroll.phase,
                momentumPhase: scroll.momentumPhase
            )
        }
    }

    public var inputEvent: InputEvent {
        let eventKind: InputEventKind
        switch kind {
        case .pointerMove(let dx, let dy):
            eventKind = .pointerMove(PointerMoveEvent(dx: dx, dy: dy))
        case .pointerButton(let button, let phase):
            eventKind = .pointerButton(PointerButtonEvent(button: button, phase: phase))
        case .tap(let button):
            eventKind = .tap(TapEvent(button: button))
        case .scroll(let dx, let dy, let phase, let momentumPhase):
            eventKind = .scroll(ScrollEvent(dx: dx, dy: dy, phase: phase, momentumPhase: momentumPhase))
        }

        return InputEvent(
            sequenceNumber: sequenceNumber,
            timestampNanos: timestampNanos,
            kind: eventKind
        )
    }
}

public enum InputReportKind: Equatable, Sendable {
    case pointerMove(dx: Double, dy: Double)
    case pointerButton(button: PointerButton, phase: ButtonPhase)
    case tap(button: PointerButton)
    case scroll(dx: Double, dy: Double, phase: ScrollPhase, momentumPhase: ScrollPhase?)
}
