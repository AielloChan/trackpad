import Foundation
#if SWIFT_PACKAGE
import TrackpadKit
#endif

public struct InputEventTuning: Equatable, Sendable {
    public let pointerSpeedMultiplier: Double

    public init(pointerSpeedMultiplier: Double) {
        self.pointerSpeedMultiplier = min(max(pointerSpeedMultiplier, 0.2), 3)
    }

    public func apply(to events: [InputEvent]) -> [InputEvent] {
        events.map(apply)
    }

    public func apply(to event: InputEvent) -> InputEvent {
        guard case .pointerMove(let move) = event.kind else {
            return event
        }

        return InputEvent(
            version: event.version,
            sequenceNumber: event.sequenceNumber,
            timestampNanos: event.timestampNanos,
            kind: .pointerMove(PointerMoveEvent(
                dx: move.dx * pointerSpeedMultiplier,
                dy: move.dy * pointerSpeedMultiplier
            ))
        )
    }
}
