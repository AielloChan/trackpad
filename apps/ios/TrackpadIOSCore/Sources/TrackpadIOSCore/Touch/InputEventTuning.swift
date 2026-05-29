import Foundation
#if SWIFT_PACKAGE
import TrackpadKit
#endif

public struct InputEventTuningState: Equatable, Sendable {
    var remainingLimitedDragStartupMoves: Int
    var remainingLimitedPointerStartupMoves: Int

    public init(
        remainingLimitedDragStartupMoves: Int = 0,
        remainingLimitedPointerStartupMoves: Int = 0
    ) {
        self.remainingLimitedDragStartupMoves = remainingLimitedDragStartupMoves
        self.remainingLimitedPointerStartupMoves = remainingLimitedPointerStartupMoves
    }
}

public struct InputEventTuning: Equatable, Sendable {
    public let pointerSpeedMultiplier: Double
    private let maximumDragStartupMoveDelta: Double = 3
    private let limitedDragStartupMoveCount = 3
    private let limitedPointerStartupMoveCount = 3

    public init(pointerSpeedMultiplier: Double) {
        self.pointerSpeedMultiplier = min(max(pointerSpeedMultiplier, 0.2), 10)
    }

    public func apply(to events: [InputEvent]) -> [InputEvent] {
        var state = InputEventTuningState()
        return apply(to: events, state: &state)
    }

    public func apply(to events: [InputEvent], state: inout InputEventTuningState) -> [InputEvent] {
        return events.map { event in
            if case .pointerButton(let button) = event.kind,
               button.button == .left,
               button.phase == .down {
                state.remainingLimitedDragStartupMoves = limitedDragStartupMoveCount
                state.remainingLimitedPointerStartupMoves = 0
                return event
            }

            if case .pointerButton(let button) = event.kind,
               button.button == .left,
               button.phase == .up {
                state.remainingLimitedDragStartupMoves = 0
                return event
            }

            if case .contact(let contact) = event.kind,
               contact.phase == .began {
                state.remainingLimitedPointerStartupMoves = limitedPointerStartupMoveCount
                return event
            }

            let tunedEvent = apply(to: event)
            if case .pointerMove(let move) = tunedEvent.kind {
                if state.remainingLimitedDragStartupMoves > 0 {
                    state.remainingLimitedDragStartupMoves -= 1
                    return limitedPointerMoveEvent(from: tunedEvent, move: move)
                }

                if state.remainingLimitedPointerStartupMoves > 0 {
                    state.remainingLimitedPointerStartupMoves -= 1
                    return limitedPointerMoveEvent(from: tunedEvent, move: move)
                }
            }

            return tunedEvent
        }
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

    private func clamped(_ value: Double, to limit: Double) -> Double {
        return min(max(value, -limit), limit)
    }

    private func limitedPointerMoveEvent(from event: InputEvent, move: PointerMoveEvent) -> InputEvent {
        return InputEvent(
            version: event.version,
            sequenceNumber: event.sequenceNumber,
            timestampNanos: event.timestampNanos,
            kind: .pointerMove(PointerMoveEvent(
                dx: clamped(move.dx, to: maximumDragStartupMoveDelta),
                dy: clamped(move.dy, to: maximumDragStartupMoveDelta)
            ))
        )
    }
}
