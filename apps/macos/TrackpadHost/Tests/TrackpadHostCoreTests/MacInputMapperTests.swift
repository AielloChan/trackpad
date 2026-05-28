import Testing
import TrackpadKit
@testable import TrackpadHostCore

@Test func pointerMoveMapsToMoveCommand() {
    var mapper = MacInputMapper()
    let event = InputEvent(
        sequenceNumber: 1,
        timestampNanos: 10,
        kind: .pointerMove(PointerMoveEvent(dx: 4, dy: -2))
    )

    #expect(mapper.commands(for: event) == [
        .move(dx: 4, dy: -2),
    ])
}

@Test func tapMapsToButtonDownAndUpCommands() {
    var mapper = MacInputMapper()
    let event = InputEvent(
        sequenceNumber: 2,
        timestampNanos: 11,
        kind: .tap(TapEvent(button: .right))
    )

    #expect(mapper.commands(for: event) == [
        .button(button: .right, phase: .down, clickCount: 1),
        .button(button: .right, phase: .up, clickCount: 1),
    ])
}

@Test func twoTapsInsideDoubleClickIntervalMapSecondTapToClickCountTwo() {
    var mapper = MacInputMapper(doubleClickIntervalSeconds: 0.5)
    let first = InputEvent(
        sequenceNumber: 20,
        timestampNanos: 1_000_000_000,
        kind: .tap(TapEvent(button: .left))
    )
    let second = InputEvent(
        sequenceNumber: 21,
        timestampNanos: 1_200_000_000,
        kind: .tap(TapEvent(button: .left))
    )

    #expect(mapper.commands(for: first) == [
        .button(button: .left, phase: .down, clickCount: 1),
        .button(button: .left, phase: .up, clickCount: 1),
    ])
    #expect(mapper.commands(for: second) == [
        .button(button: .left, phase: .down, clickCount: 2),
        .button(button: .left, phase: .up, clickCount: 2),
    ])
}

@Test func twoTapsOutsideDoubleClickIntervalResetClickCount() {
    var mapper = MacInputMapper(doubleClickIntervalSeconds: 0.5)
    let first = InputEvent(
        sequenceNumber: 22,
        timestampNanos: 1_000_000_000,
        kind: .tap(TapEvent(button: .left))
    )
    let second = InputEvent(
        sequenceNumber: 23,
        timestampNanos: 1_700_000_000,
        kind: .tap(TapEvent(button: .left))
    )

    _ = mapper.commands(for: first)

    #expect(mapper.commands(for: second) == [
        .button(button: .left, phase: .down, clickCount: 1),
        .button(button: .left, phase: .up, clickCount: 1),
    ])
}

@Test func scrollMapsToScrollCommand() {
    var mapper = MacInputMapper()
    let event = InputEvent(
        sequenceNumber: 3,
        timestampNanos: 12,
        kind: .scroll(ScrollEvent(dx: 1, dy: -9, phase: .changed))
    )

    #expect(mapper.commands(for: event) == [
        .scroll(dx: 1, dy: -9, phase: .changed, momentumPhase: nil),
    ])
}

@Test func scrollMapsPhaseAndMomentumPhaseToScrollCommand() {
    var mapper = MacInputMapper()
    let event = InputEvent(
        sequenceNumber: 4,
        timestampNanos: 13,
        kind: .scroll(ScrollEvent(dx: 0, dy: -5, phase: .changed, momentumPhase: .began))
    )

    #expect(mapper.commands(for: event) == [
        .scroll(dx: 0, dy: -5, phase: .changed, momentumPhase: .began),
    ])
}

@Test func systemActionMapsToSystemActionCommand() {
    var mapper = MacInputMapper(systemGestureSettings: .allThreeFingerSwipesEnabled)
    let event = InputEvent(
        sequenceNumber: 8,
        timestampNanos: 17,
        kind: .systemAction(SystemActionEvent(action: .nextSpace))
    )

    #expect(mapper.commands(for: event) == [
        .systemAction(.nextSpace),
    ])
}

@Test func contactEventDoesNotMapToInputCommandOrResetDoubleClickState() {
    var mapper = MacInputMapper(doubleClickIntervalSeconds: 0.5)
    let firstTap = InputEvent(
        sequenceNumber: 30,
        timestampNanos: 1_000_000_000,
        kind: .tap(TapEvent(button: .left))
    )
    let contact = InputEvent(
        sequenceNumber: 31,
        timestampNanos: 1_100_000_000,
        kind: .contact(ContactEvent(phase: .began, contactCount: 1))
    )
    let secondTap = InputEvent(
        sequenceNumber: 32,
        timestampNanos: 1_200_000_000,
        kind: .tap(TapEvent(button: .left))
    )

    _ = mapper.commands(for: firstTap)

    #expect(mapper.commands(for: contact).isEmpty)
    #expect(mapper.commands(for: secondTap) == [
        .button(button: .left, phase: .down, clickCount: 2),
        .button(button: .left, phase: .up, clickCount: 2),
    ])
}

@Test func systemActionHonorsDisabledThreeFingerVerticalSwipeSetting() {
    var mapper = MacInputMapper(systemGestureSettings: MacSystemGestureSettings(
        threeFingerVerticalSwipeEnabled: false,
        threeFingerHorizontalSwipeEnabled: true,
        threeFingerDragEnabled: false
    ))
    let event = InputEvent(
        sequenceNumber: 9,
        timestampNanos: 18,
        kind: .systemAction(SystemActionEvent(action: .missionControl))
    )

    #expect(mapper.commands(for: event).isEmpty)
}

@Test func systemActionHonorsDisabledThreeFingerHorizontalSwipeSetting() {
    var mapper = MacInputMapper(systemGestureSettings: MacSystemGestureSettings(
        threeFingerVerticalSwipeEnabled: true,
        threeFingerHorizontalSwipeEnabled: false,
        threeFingerDragEnabled: false
    ))
    let event = InputEvent(
        sequenceNumber: 10,
        timestampNanos: 19,
        kind: .systemAction(SystemActionEvent(action: .nextSpace))
    )

    #expect(mapper.commands(for: event).isEmpty)
}

@Test func systemActionIsIgnoredWhenThreeFingerDragIsEnabled() {
    var mapper = MacInputMapper(systemGestureSettings: MacSystemGestureSettings(
        threeFingerVerticalSwipeEnabled: true,
        threeFingerHorizontalSwipeEnabled: true,
        threeFingerDragEnabled: true
    ))
    let event = InputEvent(
        sequenceNumber: 11,
        timestampNanos: 20,
        kind: .systemAction(SystemActionEvent(action: .appExpose))
    )

    #expect(mapper.commands(for: event).isEmpty)
}

@Test func pointerMoveWhileLeftButtonIsDownMapsToDragCommand() {
    var mapper = MacInputMapper()

    let down = InputEvent(
        sequenceNumber: 5,
        timestampNanos: 14,
        kind: .pointerButton(PointerButtonEvent(button: .left, phase: .down))
    )
    let move = InputEvent(
        sequenceNumber: 6,
        timestampNanos: 15,
        kind: .pointerMove(PointerMoveEvent(dx: 7, dy: 3))
    )
    let up = InputEvent(
        sequenceNumber: 7,
        timestampNanos: 16,
        kind: .pointerButton(PointerButtonEvent(button: .left, phase: .up))
    )

    #expect(mapper.commands(for: down) == [
        .button(button: .left, phase: .down, clickCount: 1),
    ])
    #expect(mapper.commands(for: move) == [
        .drag(button: .left, dx: 7, dy: 3),
    ])
    #expect(mapper.commands(for: up) == [
        .button(button: .left, phase: .up, clickCount: 1),
    ])
    #expect(mapper.commands(for: move) == [
        .move(dx: 7, dy: 3),
    ])
}
