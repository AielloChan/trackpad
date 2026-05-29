import Foundation
import Testing
@testable import TrackpadKit

@Test func pointerMoveEventRoundTripsThroughJSON() throws {
    let event = InputEvent(
        sequenceNumber: 42,
        timestampNanos: 1_000_000,
        kind: .pointerMove(PointerMoveEvent(dx: 12.5, dy: -3.25))
    )

    let data = try JSONEncoder().encode(event)
    let decoded = try JSONDecoder().decode(InputEvent.self, from: data)

    #expect(decoded == event)
}

@Test func pointerButtonEventRoundTripsThroughJSON() throws {
    let event = InputEvent(
        sequenceNumber: 43,
        timestampNanos: 1_000_001,
        kind: .pointerButton(PointerButtonEvent(button: .left, phase: .down))
    )

    let data = try JSONEncoder().encode(event)
    let decoded = try JSONDecoder().decode(InputEvent.self, from: data)

    #expect(decoded == event)
}

@Test func tapEventRoundTripsThroughJSON() throws {
    let event = InputEvent(
        sequenceNumber: 44,
        timestampNanos: 1_000_002,
        kind: .tap(TapEvent(button: .right))
    )

    let data = try JSONEncoder().encode(event)
    let decoded = try JSONDecoder().decode(InputEvent.self, from: data)

    #expect(decoded == event)
}

@Test func scrollEventRoundTripsThroughJSON() throws {
    let event = InputEvent(
        sequenceNumber: 45,
        timestampNanos: 1_000_003,
        kind: .scroll(ScrollEvent(dx: 0, dy: -8, phase: .changed))
    )

    let data = try JSONEncoder().encode(event)
    let decoded = try JSONDecoder().decode(InputEvent.self, from: data)

    #expect(decoded == event)
}

@Test func scrollEventPreservesMomentumPhaseThroughJSON() throws {
    let event = ScrollEvent(dx: 0, dy: -4, phase: .changed, momentumPhase: .began)

    let data = try JSONEncoder().encode(event)
    let decoded = try JSONDecoder().decode(ScrollEvent.self, from: data)

    #expect(decoded == event)
}

@Test func scrollEventDecodesPayloadWithoutMomentumPhase() throws {
    let data = Data(#"{"dx":0,"dy":-8,"phase":"changed"}"#.utf8)

    let decoded = try JSONDecoder().decode(ScrollEvent.self, from: data)

    #expect(decoded == ScrollEvent(dx: 0, dy: -8, phase: .changed))
    #expect(decoded.momentumPhase == nil)
}

@Test func systemActionEventRoundTripsThroughJSON() throws {
    let event = InputEvent(
        sequenceNumber: 46,
        timestampNanos: 1_000_004,
        kind: .systemAction(SystemActionEvent(action: .hideNotificationCenter))
    )

    let data = try JSONEncoder().encode(event)
    let decoded = try JSONDecoder().decode(InputEvent.self, from: data)

    #expect(decoded == event)
}

@Test func contactEventRoundTripsThroughJSON() throws {
    let event = InputEvent(
        sequenceNumber: 47,
        timestampNanos: 1_000_005,
        kind: .contact(ContactEvent(phase: .began, contactCount: 1))
    )

    let data = try JSONEncoder().encode(event)
    let decoded = try JSONDecoder().decode(InputEvent.self, from: data)

    #expect(decoded == event)
}
