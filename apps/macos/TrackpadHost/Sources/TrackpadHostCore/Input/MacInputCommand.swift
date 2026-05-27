import TrackpadKit

public enum MacInputCommand: Equatable, Sendable {
    case move(dx: Double, dy: Double)
    case drag(button: PointerButton, dx: Double, dy: Double)
    case button(button: PointerButton, phase: ButtonPhase, clickCount: Int)
    case scroll(dx: Double, dy: Double, phase: ScrollPhase, momentumPhase: ScrollPhase?)
}
