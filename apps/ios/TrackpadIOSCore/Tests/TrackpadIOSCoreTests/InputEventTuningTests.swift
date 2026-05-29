import Testing
import TrackpadKit
@testable import TrackpadIOSCore

@Test func pointerSpeedTuningScalesPointerMoveEventsOnly() {
    let events = [
        InputEvent(
            sequenceNumber: 1,
            timestampNanos: 10,
            kind: .pointerMove(PointerMoveEvent(dx: 4, dy: -2))
        ),
        InputEvent(
            sequenceNumber: 2,
            timestampNanos: 11,
            kind: .scroll(ScrollEvent(dx: 3, dy: -6, phase: .changed))
        ),
        InputEvent(
            sequenceNumber: 3,
            timestampNanos: 12,
            kind: .tap(TapEvent(button: .left))
        ),
    ]

    let tunedEvents = InputEventTuning(pointerSpeedMultiplier: 1.5).apply(to: events)

    #expect(tunedEvents == [
        InputEvent(
            sequenceNumber: 1,
            timestampNanos: 10,
            kind: .pointerMove(PointerMoveEvent(dx: 6, dy: -3))
        ),
        events[1],
        events[2],
    ])
}

@Test func pointerSpeedTuningClampsMultiplierToUsableRange() {
    #expect(InputEventTuning(pointerSpeedMultiplier: 0.05).pointerSpeedMultiplier == 0.2)
    #expect(InputEventTuning(pointerSpeedMultiplier: 12).pointerSpeedMultiplier == 10)
}

@Test func pointerSpeedTuningLimitsFirstDragMoveAfterScaling() {
    let events = [
        InputEvent(
            sequenceNumber: 1,
            timestampNanos: 10,
            kind: .pointerButton(PointerButtonEvent(button: .left, phase: .down))
        ),
        InputEvent(
            sequenceNumber: 2,
            timestampNanos: 10,
            kind: .pointerMove(PointerMoveEvent(dx: 3, dy: -3))
        ),
        InputEvent(
            sequenceNumber: 3,
            timestampNanos: 20,
            kind: .pointerMove(PointerMoveEvent(dx: 1, dy: -1))
        ),
    ]

    let tunedEvents = InputEventTuning(pointerSpeedMultiplier: 2.1).apply(to: events)

    #expect(tunedEvents == [
        events[0],
        InputEvent(
            sequenceNumber: 2,
            timestampNanos: 10,
            kind: .pointerMove(PointerMoveEvent(dx: 3, dy: -3))
        ),
        InputEvent(
            sequenceNumber: 3,
            timestampNanos: 20,
            kind: .pointerMove(PointerMoveEvent(dx: 2.1, dy: -2.1))
        ),
    ])
}

@Test func pointerSpeedTuningLimitsDragStartupMovesAcrossBatches() {
    let tuning = InputEventTuning(pointerSpeedMultiplier: 3.1)
    var state = InputEventTuningState()

    let firstBatch = tuning.apply(to: [
        InputEvent(
            sequenceNumber: 1,
            timestampNanos: 10,
            kind: .pointerButton(PointerButtonEvent(button: .left, phase: .down))
        ),
        InputEvent(
            sequenceNumber: 2,
            timestampNanos: 10,
            kind: .pointerMove(PointerMoveEvent(dx: -3.667, dy: 3))
        ),
    ], state: &state)
    let secondBatch = tuning.apply(to: [
        InputEvent(
            sequenceNumber: 3,
            timestampNanos: 20,
            kind: .pointerMove(PointerMoveEvent(dx: -5.667, dy: 4.333))
        ),
    ], state: &state)
    let thirdBatch = tuning.apply(to: [
        InputEvent(
            sequenceNumber: 4,
            timestampNanos: 30,
            kind: .pointerMove(PointerMoveEvent(dx: -3.667, dy: 3.667))
        ),
    ], state: &state)
    let fourthBatch = tuning.apply(to: [
        InputEvent(
            sequenceNumber: 5,
            timestampNanos: 40,
            kind: .pointerMove(PointerMoveEvent(dx: -1, dy: 0))
        ),
    ], state: &state)

    #expect(firstBatch == [
        InputEvent(
            sequenceNumber: 1,
            timestampNanos: 10,
            kind: .pointerButton(PointerButtonEvent(button: .left, phase: .down))
        ),
        InputEvent(
            sequenceNumber: 2,
            timestampNanos: 10,
            kind: .pointerMove(PointerMoveEvent(dx: -3, dy: 3))
        ),
    ])
    #expect(secondBatch == [
        InputEvent(
            sequenceNumber: 3,
            timestampNanos: 20,
            kind: .pointerMove(PointerMoveEvent(dx: -3, dy: 3))
        ),
    ])
    #expect(thirdBatch == [
        InputEvent(
            sequenceNumber: 4,
            timestampNanos: 30,
            kind: .pointerMove(PointerMoveEvent(dx: -3, dy: 3))
        ),
    ])
    #expect(fourthBatch == [
        InputEvent(
            sequenceNumber: 5,
            timestampNanos: 40,
            kind: .pointerMove(PointerMoveEvent(dx: -3.1, dy: 0))
        ),
    ])
}

@Test func pointerSpeedTuningLimitsPointerStartupMovesAcrossBatches() {
    let tuning = InputEventTuning(pointerSpeedMultiplier: 3.1)
    var state = InputEventTuningState()

    let firstBatch = tuning.apply(to: [
        InputEvent(
            sequenceNumber: 1,
            timestampNanos: 10,
            kind: .contact(ContactEvent(phase: .began, contactCount: 1))
        ),
        InputEvent(
            sequenceNumber: 2,
            timestampNanos: 10,
            kind: .pointerMove(PointerMoveEvent(dx: 3, dy: -3))
        ),
    ], state: &state)
    let secondBatch = tuning.apply(to: [
        InputEvent(
            sequenceNumber: 3,
            timestampNanos: 20,
            kind: .pointerMove(PointerMoveEvent(dx: 2, dy: 0))
        ),
    ], state: &state)
    let thirdBatch = tuning.apply(to: [
        InputEvent(
            sequenceNumber: 4,
            timestampNanos: 30,
            kind: .pointerMove(PointerMoveEvent(dx: 1, dy: 0))
        ),
    ], state: &state)
    let fourthBatch = tuning.apply(to: [
        InputEvent(
            sequenceNumber: 5,
            timestampNanos: 40,
            kind: .pointerMove(PointerMoveEvent(dx: 1, dy: 0))
        ),
    ], state: &state)

    #expect(firstBatch == [
        InputEvent(
            sequenceNumber: 1,
            timestampNanos: 10,
            kind: .contact(ContactEvent(phase: .began, contactCount: 1))
        ),
        InputEvent(
            sequenceNumber: 2,
            timestampNanos: 10,
            kind: .pointerMove(PointerMoveEvent(dx: 3, dy: -3))
        ),
    ])
    #expect(secondBatch == [
        InputEvent(
            sequenceNumber: 3,
            timestampNanos: 20,
            kind: .pointerMove(PointerMoveEvent(dx: 3, dy: 0))
        ),
    ])
    #expect(thirdBatch == [
        InputEvent(
            sequenceNumber: 4,
            timestampNanos: 30,
            kind: .pointerMove(PointerMoveEvent(dx: 3, dy: 0))
        ),
    ])
    #expect(fourthBatch == [
        InputEvent(
            sequenceNumber: 5,
            timestampNanos: 40,
            kind: .pointerMove(PointerMoveEvent(dx: 3.1, dy: 0))
        ),
    ])
}
