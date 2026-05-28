import Testing
import TrackpadKit
@testable import TrackpadIOSCore

@Test func contactBeginEmitsContactEventWithoutPointerMovement() {
    var mapper = TouchSurfaceEventMapper(timestampProvider: { 100 })

    let event = mapper.contactBegan(with: [
        TouchContact(id: 1, point: TouchPoint(x: 10, y: 20)),
    ])

    #expect(event == InputEvent(
        sequenceNumber: 1,
        timestampNanos: 100,
        kind: .contact(ContactEvent(phase: .began, contactCount: 1))
    ))
}

@Test func touchMoveEmitsPointerDeltaFromPreviousPoint() {
    var mapper = TouchSurfaceEventMapper(timestampProvider: { 200 })
    _ = mapper.begin(at: TouchPoint(x: 10, y: 20))

    _ = mapper.move(to: TouchPoint(x: 16, y: 17))
    let event = mapper.move(to: TouchPoint(x: 17, y: 16))

    #expect(event == InputEvent(
        sequenceNumber: 1,
        timestampNanos: 200,
        kind: .pointerMove(PointerMoveEvent(dx: 1, dy: -1))
    ))
}

@Test func firstLargeSingleFingerMoveRebasesWithoutPointerJump() {
    var mapper = TouchSurfaceEventMapper(timestampProvider: { 200 })
    _ = mapper.begin(at: TouchPoint(x: 10, y: 20))

    let first = mapper.move(to: TouchPoint(x: 16, y: 17))
    let second = mapper.move(to: TouchPoint(x: 17, y: 16))

    #expect(first == nil)
    #expect(second == InputEvent(
        sequenceNumber: 1,
        timestampNanos: 200,
        kind: .pointerMove(PointerMoveEvent(dx: 1, dy: -1))
    ))
}

@Test func firstSmallSingleFingerMoveStillMovesPointer() {
    var mapper = TouchSurfaceEventMapper(timestampProvider: { 200 })
    _ = mapper.begin(at: TouchPoint(x: 10, y: 20))

    let event = mapper.move(to: TouchPoint(x: 12, y: 21))

    #expect(event == InputEvent(
        sequenceNumber: 1,
        timestampNanos: 200,
        kind: .pointerMove(PointerMoveEvent(dx: 2, dy: 1))
    ))
}

@Test func touchMoveIncrementsSequenceNumber() {
    var currentTime: UInt64 = 300
    var mapper = TouchSurfaceEventMapper(timestampProvider: { currentTime })
    _ = mapper.begin(at: TouchPoint(x: 0, y: 0))

    let first = mapper.move(to: TouchPoint(x: 1, y: 0))
    currentTime = 301
    let second = mapper.move(to: TouchPoint(x: 3, y: 0))

    #expect(first?.sequenceNumber == 1)
    #expect(second?.sequenceNumber == 2)
    #expect(second?.timestampNanos == 301)
}

@Test func touchEndResetsPreviousPoint() {
    var mapper = TouchSurfaceEventMapper(timestampProvider: { 400 })
    _ = mapper.begin(at: TouchPoint(x: 0, y: 0))
    _ = mapper.move(to: TouchPoint(x: 10, y: 10))

    mapper.end()
    let event = mapper.move(to: TouchPoint(x: 20, y: 20))

    #expect(event == nil)
}

@Test func singleFingerTapEmitsLeftClickOnEnd() {
    var currentTime: UInt64 = 0
    var mapper = TouchSurfaceEventMapper(timestampProvider: { currentTime })

    let began = mapper.begin(with: [
        TouchContact(id: 1, point: TouchPoint(x: 10, y: 20)),
    ])
    currentTime = 100_000_000
    let ended = mapper.end(with: [])

    #expect(began.isEmpty)
    #expect(ended == [
        InputEvent(
            sequenceNumber: 1,
            timestampNanos: 100_000_000,
            kind: .tap(TapEvent(button: .left))
        ),
    ])
}

@Test func singleFingerHoldMoveEmitsPointerMoveWithoutDrag() {
    var currentTime: UInt64 = 0
    var mapper = TouchSurfaceEventMapper(timestampProvider: { currentTime })
    _ = mapper.begin(with: [
        TouchContact(id: 1, point: TouchPoint(x: 0, y: 0)),
    ])

    currentTime = 500_000_000
    let firstMove = mapper.move(with: [
        TouchContact(id: 1, point: TouchPoint(x: 12, y: 4)),
    ])
    let moved = mapper.move(with: [
        TouchContact(id: 1, point: TouchPoint(x: 14, y: 5)),
    ])
    currentTime = 550_000_000
    let ended = mapper.end(with: [])

    #expect(firstMove.isEmpty)
    #expect(moved == [
        InputEvent(
            sequenceNumber: 1,
            timestampNanos: 500_000_000,
            kind: .pointerMove(PointerMoveEvent(dx: 2, dy: 1))
        ),
    ])
    #expect(ended.isEmpty)
}

@Test func tapThenQuickSecondPressMoveStartsDragAndEndsWithButtonUp() {
    var currentTime: UInt64 = 0
    var mapper = TouchSurfaceEventMapper(timestampProvider: { currentTime })
    _ = mapper.begin(with: [
        TouchContact(id: 1, point: TouchPoint(x: 0, y: 0)),
    ])

    currentTime = 100_000_000
    let firstEnd = mapper.end(with: [])
    currentTime = 220_000_000
    let secondBegin = mapper.begin(with: [
        TouchContact(id: 2, point: TouchPoint(x: 0, y: 0)),
    ])
    currentTime = 260_000_000
    let firstMove = mapper.move(with: [
        TouchContact(id: 2, point: TouchPoint(x: 12, y: 0)),
    ])
    currentTime = 280_000_000
    let moved = mapper.move(with: [
        TouchContact(id: 2, point: TouchPoint(x: 14, y: 0)),
    ])
    currentTime = 300_000_000
    let secondEnd = mapper.end(with: [])

    #expect(firstEnd == [
        InputEvent(
            sequenceNumber: 1,
            timestampNanos: 100_000_000,
            kind: .tap(TapEvent(button: .left))
        ),
    ])
    #expect(secondBegin.isEmpty)
    #expect(firstMove == [
        InputEvent(
            sequenceNumber: 2,
            timestampNanos: 260_000_000,
            kind: .pointerButton(PointerButtonEvent(button: .left, phase: .down))
        ),
    ])
    #expect(moved == [
        InputEvent(
            sequenceNumber: 3,
            timestampNanos: 280_000_000,
            kind: .pointerMove(PointerMoveEvent(dx: 2, dy: 0))
        ),
    ])
    #expect(secondEnd == [
        InputEvent(
            sequenceNumber: 4,
            timestampNanos: 300_000_000,
            kind: .pointerButton(PointerButtonEvent(button: .left, phase: .up))
        ),
    ])
}

@Test func tapThenSecondPressAfterDefaultDragWindowDoesNotStartDrag() {
    var currentTime: UInt64 = 0
    var mapper = TouchSurfaceEventMapper(timestampProvider: { currentTime })
    _ = mapper.begin(with: [
        TouchContact(id: 1, point: TouchPoint(x: 0, y: 0)),
    ])

    currentTime = 100_000_000
    _ = mapper.end(with: [])
    currentTime = 250_000_000
    let secondBegin = mapper.begin(with: [
        TouchContact(id: 2, point: TouchPoint(x: 0, y: 0)),
    ])
    currentTime = 290_000_000
    let firstMove = mapper.move(with: [
        TouchContact(id: 2, point: TouchPoint(x: 12, y: 0)),
    ])
    let moved = mapper.move(with: [
        TouchContact(id: 2, point: TouchPoint(x: 14, y: 0)),
    ])
    currentTime = 330_000_000
    let secondEnd = mapper.end(with: [])

    #expect(secondBegin.isEmpty)
    #expect(firstMove.isEmpty)
    #expect(moved == [
        InputEvent(
            sequenceNumber: 2,
            timestampNanos: 290_000_000,
            kind: .pointerMove(PointerMoveEvent(dx: 2, dy: 0))
        ),
    ])
    #expect(secondEnd.isEmpty)
}

@Test func tapThenSecondPressSmallMoveStartsDragWithoutMovementDeadZone() {
    var currentTime: UInt64 = 0
    var mapper = TouchSurfaceEventMapper(timestampProvider: { currentTime })
    _ = mapper.begin(with: [
        TouchContact(id: 1, point: TouchPoint(x: 0, y: 0)),
    ])

    currentTime = 100_000_000
    _ = mapper.end(with: [])
    currentTime = 180_000_000
    _ = mapper.begin(with: [
        TouchContact(id: 2, point: TouchPoint(x: 0, y: 0)),
    ])
    currentTime = 220_000_000
    let moved = mapper.move(with: [
        TouchContact(id: 2, point: TouchPoint(x: 3, y: 2)),
    ])

    #expect(moved == [
        InputEvent(
            sequenceNumber: 2,
            timestampNanos: 220_000_000,
            kind: .pointerButton(PointerButtonEvent(button: .left, phase: .down))
        ),
        InputEvent(
            sequenceNumber: 3,
            timestampNanos: 220_000_000,
            kind: .pointerMove(PointerMoveEvent(dx: 3, dy: 2))
        ),
    ])
}

@Test func tapDragCandidateRebasesLargeFirstMoveButKeepsDragActive() {
    var currentTime: UInt64 = 0
    var mapper = TouchSurfaceEventMapper(timestampProvider: { currentTime })
    _ = mapper.begin(with: [
        TouchContact(id: 1, point: TouchPoint(x: 0, y: 0)),
    ])

    currentTime = 100_000_000
    _ = mapper.end(with: [])
    currentTime = 180_000_000
    _ = mapper.begin(with: [
        TouchContact(id: 2, point: TouchPoint(x: 0, y: 0)),
    ])
    currentTime = 220_000_000
    let firstMove = mapper.move(with: [
        TouchContact(id: 2, point: TouchPoint(x: 10.5, y: -3)),
    ])
    currentTime = 236_000_000
    let secondMove = mapper.move(with: [
        TouchContact(id: 2, point: TouchPoint(x: 11, y: -3)),
    ])

    #expect(firstMove == [
        InputEvent(
            sequenceNumber: 2,
            timestampNanos: 220_000_000,
            kind: .pointerButton(PointerButtonEvent(button: .left, phase: .down))
        ),
    ])
    #expect(secondMove == [
        InputEvent(
            sequenceNumber: 3,
            timestampNanos: 236_000_000,
            kind: .pointerMove(PointerMoveEvent(dx: 0.5, dy: 0))
        ),
    ])
}

@Test func customTapDragIntervalAllowsLongerSecondPressDelay() {
    var currentTime: UInt64 = 0
    var mapper = TouchSurfaceEventMapper(
        timestampProvider: { currentTime },
        gestureConfiguration: TouchGestureConfiguration(tapDragMaximumIntervalMilliseconds: 180)
    )
    _ = mapper.begin(with: [
        TouchContact(id: 1, point: TouchPoint(x: 0, y: 0)),
    ])

    currentTime = 100_000_000
    _ = mapper.end(with: [])
    currentTime = 260_000_000
    _ = mapper.begin(with: [
        TouchContact(id: 2, point: TouchPoint(x: 0, y: 0)),
    ])
    currentTime = 300_000_000
    let moved = mapper.move(with: [
        TouchContact(id: 2, point: TouchPoint(x: 3, y: 0)),
    ])

    #expect(moved == [
        InputEvent(
            sequenceNumber: 2,
            timestampNanos: 300_000_000,
            kind: .pointerButton(PointerButtonEvent(button: .left, phase: .down))
        ),
        InputEvent(
            sequenceNumber: 3,
            timestampNanos: 300_000_000,
            kind: .pointerMove(PointerMoveEvent(dx: 3, dy: 0))
        ),
    ])
}

@Test func twoFingerTapEmitsRightClickOnEnd() {
    var currentTime: UInt64 = 0
    var mapper = TouchSurfaceEventMapper(timestampProvider: { currentTime })

    _ = mapper.begin(with: [
        TouchContact(id: 1, point: TouchPoint(x: 10, y: 20)),
        TouchContact(id: 2, point: TouchPoint(x: 40, y: 20)),
    ])
    currentTime = 120_000_000
    let ended = mapper.end(with: [])

    #expect(ended == [
        InputEvent(
            sequenceNumber: 1,
            timestampNanos: 120_000_000,
            kind: .tap(TapEvent(button: .right))
        ),
    ])
}

@Test func twoFingerMoveEmitsScrollWithPhases() {
    var currentTime: UInt64 = 0
    var mapper = TouchSurfaceEventMapper(timestampProvider: { currentTime })
    _ = mapper.begin(with: [
        TouchContact(id: 1, point: TouchPoint(x: 10, y: 10)),
        TouchContact(id: 2, point: TouchPoint(x: 30, y: 10)),
    ])

    currentTime = 100
    let firstMove = mapper.move(with: [
        TouchContact(id: 1, point: TouchPoint(x: 10, y: 16)),
        TouchContact(id: 2, point: TouchPoint(x: 30, y: 16)),
    ])
    currentTime = 200
    let secondMove = mapper.move(with: [
        TouchContact(id: 1, point: TouchPoint(x: 10, y: 25)),
        TouchContact(id: 2, point: TouchPoint(x: 30, y: 25)),
    ])
    currentTime = 300
    let ended = mapper.end(with: [])

    #expect(firstMove == [
        InputEvent(
            sequenceNumber: 1,
            timestampNanos: 100,
            kind: .scroll(ScrollEvent(dx: 0, dy: 6, phase: .began))
        ),
    ])
    #expect(secondMove == [
        InputEvent(
            sequenceNumber: 2,
            timestampNanos: 200,
            kind: .scroll(ScrollEvent(dx: 0, dy: 9, phase: .changed))
        ),
    ])
    #expect(ended == [
        InputEvent(
            sequenceNumber: 3,
            timestampNanos: 300,
            kind: .scroll(ScrollEvent(dx: 0, dy: 0, phase: .ended))
        ),
    ])
}

@Test func twoFingerScrollEndsWhenOneFingerIsReleasedWithoutStartingSingleFingerTap() {
    var currentTime: UInt64 = 0
    var mapper = TouchSurfaceEventMapper(timestampProvider: { currentTime })
    _ = mapper.begin(with: [
        TouchContact(id: 1, point: TouchPoint(x: 10, y: 10)),
        TouchContact(id: 2, point: TouchPoint(x: 30, y: 10)),
    ])

    currentTime = 100
    _ = mapper.move(with: [
        TouchContact(id: 1, point: TouchPoint(x: 10, y: 22)),
        TouchContact(id: 2, point: TouchPoint(x: 30, y: 22)),
    ])
    currentTime = 200
    let partialEnd = mapper.end(with: [
        TouchContact(id: 2, point: TouchPoint(x: 30, y: 22)),
    ])
    currentTime = 240
    let finalEnd = mapper.end(with: [])

    #expect(partialEnd == [
        InputEvent(
            sequenceNumber: 2,
            timestampNanos: 200,
            kind: .scroll(ScrollEvent(dx: 0, dy: 0, phase: .ended))
        ),
    ])
    #expect(finalEnd.isEmpty)
}

@Test func twoFingerScrollIgnoresSingleRemainingFingerMoveBeforeEnd() {
    var currentTime: UInt64 = 0
    var mapper = TouchSurfaceEventMapper(timestampProvider: { currentTime })
    _ = mapper.begin(with: [
        TouchContact(id: 1, point: TouchPoint(x: 10, y: 10)),
        TouchContact(id: 2, point: TouchPoint(x: 90, y: 10)),
    ])

    currentTime = 100
    let scroll = mapper.move(with: [
        TouchContact(id: 1, point: TouchPoint(x: 10, y: 50)),
        TouchContact(id: 2, point: TouchPoint(x: 90, y: 50)),
    ])
    currentTime = 120
    let terminalSingleFingerMove = mapper.move(with: [
        TouchContact(id: 2, point: TouchPoint(x: 90, y: 52)),
    ])
    currentTime = 130
    let ended = mapper.end(with: [
        TouchContact(id: 2, point: TouchPoint(x: 90, y: 52)),
    ])

    #expect(scroll == [
        InputEvent(
            sequenceNumber: 1,
            timestampNanos: 100,
            kind: .scroll(ScrollEvent(dx: 0, dy: 40, phase: .began))
        ),
    ])
    #expect(terminalSingleFingerMove.isEmpty)
    #expect(ended == [
        InputEvent(
            sequenceNumber: 2,
            timestampNanos: 130,
            kind: .scroll(ScrollEvent(dx: 0, dy: 0, phase: .ended))
        ),
    ])
}

@Test func threeFingerSwipeUpEmitsMissionControlOnce() {
    var currentTime: UInt64 = 0
    var mapper = TouchSurfaceEventMapper(timestampProvider: { currentTime })
    _ = mapper.begin(with: threeFingerContacts(y: 120))

    currentTime = 100
    let smallMove = mapper.move(with: threeFingerContacts(y: 95))
    currentTime = 200
    let swipe = mapper.move(with: threeFingerContacts(y: 55))
    currentTime = 300
    let continuedMove = mapper.move(with: threeFingerContacts(y: 20))
    currentTime = 400
    let ended = mapper.end(with: [])

    #expect(smallMove.isEmpty)
    #expect(swipe == [
        InputEvent(
            sequenceNumber: 1,
            timestampNanos: 200,
            kind: .systemAction(SystemActionEvent(action: .missionControl))
        ),
    ])
    #expect(continuedMove.isEmpty)
    #expect(ended.isEmpty)
}

@Test func threeFingerSwipeMapsSingleMovingContactToPointerMove() {
    var currentTime: UInt64 = 0
    var mapper = TouchSurfaceEventMapper(timestampProvider: { currentTime })
    _ = mapper.begin(with: [
        TouchContact(id: 1, point: TouchPoint(x: 100, y: 100)),
        TouchContact(id: 2, point: TouchPoint(x: 140, y: 100)),
        TouchContact(id: 3, point: TouchPoint(x: 180, y: 100)),
    ])

    currentTime = 100
    let singleMovingContact = mapper.move(with: [
        TouchContact(id: 1, point: TouchPoint(x: -100, y: 100)),
        TouchContact(id: 2, point: TouchPoint(x: 140, y: 100)),
        TouchContact(id: 3, point: TouchPoint(x: 180, y: 100)),
    ])

    #expect(singleMovingContact == [
        InputEvent(
            sequenceNumber: 1,
            timestampNanos: 100,
            kind: .pointerMove(PointerMoveEvent(dx: -200, dy: 0))
        ),
    ])
}

@Test func threeFingerSwipeRequiresAtLeastTwoMovingContacts() {
    var currentTime: UInt64 = 0
    var mapper = TouchSurfaceEventMapper(timestampProvider: { currentTime })
    _ = mapper.begin(with: [
        TouchContact(id: 1, point: TouchPoint(x: 100, y: 100)),
        TouchContact(id: 2, point: TouchPoint(x: 140, y: 100)),
        TouchContact(id: 3, point: TouchPoint(x: 180, y: 100)),
    ])

    currentTime = 100
    let swipe = mapper.move(with: [
        TouchContact(id: 1, point: TouchPoint(x: -20, y: 100)),
        TouchContact(id: 2, point: TouchPoint(x: 20, y: 100)),
        TouchContact(id: 3, point: TouchPoint(x: 180, y: 100)),
    ])

    #expect(swipe == [
        InputEvent(
            sequenceNumber: 1,
            timestampNanos: 100,
            kind: .systemAction(SystemActionEvent(action: .nextSpace))
        ),
    ])
}

@Test func threeFingerSwipeAllowsTransientAdditionalContact() {
    var currentTime: UInt64 = 0
    var mapper = TouchSurfaceEventMapper(timestampProvider: { currentTime })
    _ = mapper.begin(with: [
        TouchContact(id: 1, point: TouchPoint(x: 100, y: 100)),
        TouchContact(id: 2, point: TouchPoint(x: 140, y: 100)),
        TouchContact(id: 3, point: TouchPoint(x: 180, y: 100)),
    ])

    currentTime = 100
    let swipe = mapper.move(with: [
        TouchContact(id: 1, point: TouchPoint(x: -100, y: 100)),
        TouchContact(id: 2, point: TouchPoint(x: -60, y: 100)),
        TouchContact(id: 3, point: TouchPoint(x: 180, y: 100)),
        TouchContact(id: 4, point: TouchPoint(x: 200, y: 100)),
    ])

    #expect(swipe == [
        InputEvent(
            sequenceNumber: 1,
            timestampNanos: 100,
            kind: .systemAction(SystemActionEvent(action: .nextSpace))
        ),
    ])
}

@Test func threeFingerSwipeSessionResetsOnlyAfterAllContactsEnd() {
    var currentTime: UInt64 = 0
    var mapper = TouchSurfaceEventMapper(timestampProvider: { currentTime })
    _ = mapper.begin(with: [
        TouchContact(id: 1, point: TouchPoint(x: 100, y: 100)),
        TouchContact(id: 2, point: TouchPoint(x: 140, y: 100)),
        TouchContact(id: 3, point: TouchPoint(x: 180, y: 100)),
    ])

    currentTime = 100
    let firstAction = mapper.move(with: [
        TouchContact(id: 1, point: TouchPoint(x: 30, y: 100)),
        TouchContact(id: 2, point: TouchPoint(x: 70, y: 100)),
        TouchContact(id: 3, point: TouchPoint(x: 110, y: 100)),
    ])
    currentTime = 200
    let partialLift = mapper.end(with: [
        TouchContact(id: 1, point: TouchPoint(x: 30, y: 100)),
        TouchContact(id: 2, point: TouchPoint(x: 70, y: 100)),
    ])
    currentTime = 300
    let oppositeMoveBeforeAllContactsEnd = mapper.move(with: [
        TouchContact(id: 1, point: TouchPoint(x: 150, y: 100)),
        TouchContact(id: 2, point: TouchPoint(x: 190, y: 100)),
    ])
    currentTime = 400
    let fullLift = mapper.end(with: [])
    currentTime = 500
    _ = mapper.begin(with: [
        TouchContact(id: 4, point: TouchPoint(x: 100, y: 100)),
        TouchContact(id: 5, point: TouchPoint(x: 140, y: 100)),
        TouchContact(id: 6, point: TouchPoint(x: 180, y: 100)),
    ])
    currentTime = 600
    let actionAfterFullLift = mapper.move(with: [
        TouchContact(id: 4, point: TouchPoint(x: 190, y: 100)),
        TouchContact(id: 5, point: TouchPoint(x: 230, y: 100)),
        TouchContact(id: 6, point: TouchPoint(x: 270, y: 100)),
    ])

    #expect(firstAction == [
        InputEvent(
            sequenceNumber: 1,
            timestampNanos: 100,
            kind: .systemAction(SystemActionEvent(action: .nextSpace))
        ),
    ])
    #expect(partialLift.isEmpty)
    #expect(oppositeMoveBeforeAllContactsEnd.isEmpty)
    #expect(fullLift.isEmpty)
    #expect(actionAfterFullLift == [
        InputEvent(
            sequenceNumber: 2,
            timestampNanos: 600,
            kind: .systemAction(SystemActionEvent(action: .previousSpace))
        ),
    ])
}

@Test func threeFingerSwipeDirectionsMapToSystemActions() {
    #expect(threeFingerSwipeAction(from: TouchPoint(x: 100, y: 100), to: TouchPoint(x: 100, y: 170)) == .appExpose)
    #expect(threeFingerSwipeAction(from: TouchPoint(x: 100, y: 100), to: TouchPoint(x: 25, y: 100)) == .nextSpace)
    #expect(threeFingerSwipeAction(from: TouchPoint(x: 100, y: 100), to: TouchPoint(x: 175, y: 100)) == .previousSpace)
}

@Test func threeFingerSystemActionSuppressesSingleFingerTapImmediatelyAfterRelease() {
    var currentTime: UInt64 = 0
    var mapper = TouchSurfaceEventMapper(timestampProvider: { currentTime })
    _ = mapper.begin(with: [
        TouchContact(id: 1, point: TouchPoint(x: 100, y: 100)),
        TouchContact(id: 2, point: TouchPoint(x: 140, y: 100)),
        TouchContact(id: 3, point: TouchPoint(x: 180, y: 100)),
    ])

    currentTime = 100_000_000
    _ = mapper.move(with: [
        TouchContact(id: 1, point: TouchPoint(x: 30, y: 100)),
        TouchContact(id: 2, point: TouchPoint(x: 70, y: 100)),
        TouchContact(id: 3, point: TouchPoint(x: 110, y: 100)),
    ])
    currentTime = 200_000_000
    _ = mapper.end(with: [])
    currentTime = 230_000_000
    let suppressedBegin = mapper.begin(with: [
        TouchContact(id: 4, point: TouchPoint(x: 40, y: 40)),
    ])
    currentTime = 250_000_000
    let suppressedEnd = mapper.end(with: [])

    #expect(suppressedBegin.isEmpty)
    #expect(suppressedEnd.isEmpty)
}

@Test func threeFingerSystemActionSuppressesResidualTwoFingerTapAfterRelease() {
    var currentTime: UInt64 = 0
    var mapper = TouchSurfaceEventMapper(timestampProvider: { currentTime })
    _ = mapper.begin(with: [
        TouchContact(id: 1, point: TouchPoint(x: 100, y: 100)),
        TouchContact(id: 2, point: TouchPoint(x: 140, y: 100)),
        TouchContact(id: 3, point: TouchPoint(x: 180, y: 100)),
    ])

    currentTime = 100_000_000
    _ = mapper.move(with: [
        TouchContact(id: 1, point: TouchPoint(x: 30, y: 100)),
        TouchContact(id: 2, point: TouchPoint(x: 70, y: 100)),
        TouchContact(id: 3, point: TouchPoint(x: 110, y: 100)),
    ])
    currentTime = 200_000_000
    _ = mapper.end(with: [])
    currentTime = 260_000_000
    let suppressedBegin = mapper.begin(with: [
        TouchContact(id: 4, point: TouchPoint(x: 40, y: 40)),
        TouchContact(id: 5, point: TouchPoint(x: 80, y: 40)),
    ])
    currentTime = 280_000_000
    let suppressedEnd = mapper.end(with: [])

    #expect(suppressedBegin.isEmpty)
    #expect(suppressedEnd.isEmpty)
}

@Test func threeFingerSystemActionAllowsImmediateOppositeSystemActionAfterRelease() {
    var currentTime: UInt64 = 0
    var mapper = TouchSurfaceEventMapper(timestampProvider: { currentTime })
    _ = mapper.begin(with: [
        TouchContact(id: 1, point: TouchPoint(x: 100, y: 100)),
        TouchContact(id: 2, point: TouchPoint(x: 140, y: 100)),
        TouchContact(id: 3, point: TouchPoint(x: 180, y: 100)),
    ])

    currentTime = 100_000_000
    let firstAction = mapper.move(with: [
        TouchContact(id: 1, point: TouchPoint(x: 30, y: 100)),
        TouchContact(id: 2, point: TouchPoint(x: 70, y: 100)),
        TouchContact(id: 3, point: TouchPoint(x: 110, y: 100)),
    ])
    currentTime = 200_000_000
    _ = mapper.end(with: [])
    currentTime = 260_000_000
    _ = mapper.begin(with: [
        TouchContact(id: 1, point: TouchPoint(x: 30, y: 100)),
        TouchContact(id: 2, point: TouchPoint(x: 70, y: 100)),
        TouchContact(id: 3, point: TouchPoint(x: 110, y: 100)),
    ])
    currentTime = 300_000_000
    let oppositeAction = mapper.move(with: [
        TouchContact(id: 1, point: TouchPoint(x: 120, y: 100)),
        TouchContact(id: 2, point: TouchPoint(x: 160, y: 100)),
        TouchContact(id: 3, point: TouchPoint(x: 200, y: 100)),
    ])

    #expect(firstAction == [
        InputEvent(
            sequenceNumber: 1,
            timestampNanos: 100_000_000,
            kind: .systemAction(SystemActionEvent(action: .nextSpace))
        ),
    ])
    #expect(oppositeAction == [
        InputEvent(
            sequenceNumber: 2,
            timestampNanos: 300_000_000,
            kind: .systemAction(SystemActionEvent(action: .previousSpace))
        ),
    ])
}

@Test func twoFingerScrollSuppressesSingleFingerTapImmediatelyAfterRelease() {
    var currentTime: UInt64 = 0
    var mapper = TouchSurfaceEventMapper(timestampProvider: { currentTime })
    _ = mapper.begin(with: [
        TouchContact(id: 1, point: TouchPoint(x: 10, y: 10)),
        TouchContact(id: 2, point: TouchPoint(x: 30, y: 10)),
    ])

    currentTime = 100_000_000
    _ = mapper.move(with: [
        TouchContact(id: 1, point: TouchPoint(x: 10, y: 22)),
        TouchContact(id: 2, point: TouchPoint(x: 30, y: 22)),
    ])
    currentTime = 200_000_000
    _ = mapper.end(with: [])
    currentTime = 230_000_000
    let suppressedBegin = mapper.begin(with: [
        TouchContact(id: 3, point: TouchPoint(x: 40, y: 40)),
    ])
    currentTime = 250_000_000
    let suppressedEnd = mapper.end(with: [])

    #expect(suppressedBegin.isEmpty)
    #expect(suppressedEnd.isEmpty)
}

private func threeFingerSwipeAction(from start: TouchPoint, to end: TouchPoint) -> SystemAction? {
    var currentTime: UInt64 = 0
    var mapper = TouchSurfaceEventMapper(timestampProvider: { currentTime })
    _ = mapper.begin(with: [
        TouchContact(id: 1, point: start),
        TouchContact(id: 2, point: start),
        TouchContact(id: 3, point: start),
    ])

    currentTime = 100
    return mapper.move(with: [
        TouchContact(id: 1, point: end),
        TouchContact(id: 2, point: end),
        TouchContact(id: 3, point: end),
    ]).compactMap { event in
        if case .systemAction(let systemAction) = event.kind {
            return systemAction.action
        }
        return nil
    }.first
}

private func threeFingerContacts(y: Double) -> [TouchContact] {
    [
        TouchContact(id: 1, point: TouchPoint(x: 40, y: y)),
        TouchContact(id: 2, point: TouchPoint(x: 80, y: y)),
        TouchContact(id: 3, point: TouchPoint(x: 120, y: y)),
    ]
}

@Test func singleFingerTapWorksAfterTwoFingerScrollSuppressionWindow() {
    var currentTime: UInt64 = 0
    var mapper = TouchSurfaceEventMapper(timestampProvider: { currentTime })
    _ = mapper.begin(with: [
        TouchContact(id: 1, point: TouchPoint(x: 10, y: 10)),
        TouchContact(id: 2, point: TouchPoint(x: 30, y: 10)),
    ])

    currentTime = 100_000_000
    _ = mapper.move(with: [
        TouchContact(id: 1, point: TouchPoint(x: 10, y: 22)),
        TouchContact(id: 2, point: TouchPoint(x: 30, y: 22)),
    ])
    currentTime = 200_000_000
    _ = mapper.end(with: [])
    currentTime = 281_000_000
    let tapBegin = mapper.begin(with: [
        TouchContact(id: 3, point: TouchPoint(x: 40, y: 40)),
    ])
    currentTime = 320_000_000
    let tapEnd = mapper.end(with: [])

    #expect(tapBegin.isEmpty)
    #expect(tapEnd == [
        InputEvent(
            sequenceNumber: 3,
            timestampNanos: 320_000_000,
            kind: .tap(TapEvent(button: .left))
        ),
    ])
}
