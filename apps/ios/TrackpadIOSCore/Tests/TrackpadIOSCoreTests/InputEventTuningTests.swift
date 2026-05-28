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
