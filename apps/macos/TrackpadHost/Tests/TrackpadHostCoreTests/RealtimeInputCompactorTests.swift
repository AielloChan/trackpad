import Testing
import TrackpadKit
@testable import TrackpadHostCore

@Test func realtimeInputCompactorCoalescesConsecutivePointerMoves() {
    let compactor = RealtimeInputCompactor(maxRealtimeAgeNanos: 1_000)

    let compacted = compactor.compact([
        .input(pointerMove(sequence: 1, dx: 1, dy: 2)),
        .input(pointerMove(sequence: 2, dx: 3, dy: -1)),
    ])

    #expect(compacted == [
        .input(pointerMove(sequence: 2, dx: 4, dy: 1)),
    ])
}

@Test func realtimeInputCompactorKeepsBoundaryEventsWhileDroppingStaleRealtimeEvents() {
    let compactor = RealtimeInputCompactor(maxRealtimeAgeNanos: 10)
    let button = InputEvent(
        sequenceNumber: 2,
        timestampNanos: 100,
        kind: .pointerButton(PointerButtonEvent(button: .left, phase: .down))
    )

    let compacted = compactor.compact([
        .input(pointerMove(sequence: 1, timestamp: 1, dx: 20, dy: 0)),
        .input(button),
        .input(scrollChanged(sequence: 3, timestamp: 2, dx: 0, dy: 40)),
        .input(pointerMove(sequence: 4, timestamp: 100, dx: 2, dy: 0)),
    ])

    #expect(compacted == [
        .input(button),
        .input(pointerMove(sequence: 4, timestamp: 100, dx: 2, dy: 0)),
    ])
}

@Test func realtimeInputCompactorDoesNotCoalesceAcrossFrames() {
    let compactor = RealtimeInputCompactor(maxRealtimeAgeNanos: 1_000)
    let pong = SessionFrame.pong(SessionPong(id: 1, clientSentNanos: 10, hostReceivedNanos: 20))

    let compacted = compactor.compact([
        .input(pointerMove(sequence: 1, dx: 1, dy: 0)),
        .frame(pong),
        .input(pointerMove(sequence: 2, dx: 2, dy: 0)),
    ])

    #expect(compacted == [
        .input(pointerMove(sequence: 1, dx: 1, dy: 0)),
        .frame(pong),
        .input(pointerMove(sequence: 2, dx: 2, dy: 0)),
    ])
}

private func pointerMove(sequence: UInt64, dx: Double, dy: Double) -> InputEvent {
    pointerMove(sequence: sequence, timestamp: sequence, dx: dx, dy: dy)
}

private func pointerMove(sequence: UInt64, timestamp: UInt64, dx: Double, dy: Double) -> InputEvent {
    InputEvent(
        sequenceNumber: sequence,
        timestampNanos: timestamp,
        kind: .pointerMove(PointerMoveEvent(dx: dx, dy: dy))
    )
}

private func scrollChanged(sequence: UInt64, timestamp: UInt64, dx: Double, dy: Double) -> InputEvent {
    InputEvent(
        sequenceNumber: sequence,
        timestampNanos: timestamp,
        kind: .scroll(ScrollEvent(dx: dx, dy: dy, phase: .changed))
    )
}
