import Foundation
#if SWIFT_PACKAGE
import TrackpadKit
#endif

public struct TouchPoint: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct TouchContact: Equatable, Sendable {
    public let id: Int
    public let point: TouchPoint

    public init(id: Int, point: TouchPoint) {
        self.id = id
        self.point = point
    }
}

public struct TouchGestureConfiguration: Equatable, Sendable {
    public let tapMaximumDurationNanos: UInt64
    public let tapDragMaximumIntervalNanos: UInt64
    public let scrollReleaseTapSuppressionNanos: UInt64
    public let systemActionReleaseSuppressionNanos: UInt64

    public init(
        tapMaximumDurationMilliseconds: Double = 250,
        tapDragMaximumIntervalMilliseconds: Double = 140,
        scrollReleaseTapSuppressionMilliseconds: Double = 80,
        systemActionReleaseSuppressionMilliseconds: Double = 320
    ) {
        tapMaximumDurationNanos = Self.nanoseconds(from: tapMaximumDurationMilliseconds, range: 60...500)
        tapDragMaximumIntervalNanos = Self.nanoseconds(from: tapDragMaximumIntervalMilliseconds, range: 40...250)
        scrollReleaseTapSuppressionNanos = Self.nanoseconds(from: scrollReleaseTapSuppressionMilliseconds, range: 0...250)
        systemActionReleaseSuppressionNanos = Self.nanoseconds(from: systemActionReleaseSuppressionMilliseconds, range: 80...600)
    }

    private static func nanoseconds(from milliseconds: Double, range: ClosedRange<Double>) -> UInt64 {
        let clampedMilliseconds = min(max(milliseconds, range.lowerBound), range.upperBound)
        return UInt64((clampedMilliseconds * 1_000_000).rounded())
    }
}

public struct TouchSurfaceEventMapper {
    private enum GestureKind {
        case singleFinger
        case twoFinger
        case threeFingerSwipe
    }

    private struct GestureState {
        var kind: GestureKind
        var startTimeNanos: UInt64
        var startPoint: TouchPoint
        var previousPoint: TouchPoint
        var previousTimeNanos: UInt64
        var maxDistanceFromStart: Double = 0
        var isDragging = false
        var isTapDragCandidate = false
        var hasProcessedSingleFingerMove = false
        var suppressSingleFingerTap = false
        var didScroll = false
        var didEmitSystemAction = false
        var threeFingerStartContacts: [Int: TouchPoint] = [:]
        var threeFingerPreviousContacts: [Int: TouchPoint] = [:]
    }

    private var gestureState: GestureState?
    private var lastSingleTapEndNanos: UInt64?
    private var suppressSingleFingerTapUntilNanos: UInt64?
    private var suppressTapUntilNanos: UInt64?
    public var gestureConfiguration: TouchGestureConfiguration
    private var nextSequenceNumber: UInt64 = 1
    private let timestampProvider: () -> UInt64
    private let tapMovementTolerance: Double = 8
    private let firstPointerMoveRebaseTolerance: Double = 3
    private let tapDragFirstMoveRebaseTolerance: Double = 8
    private let scrollMovementTolerance: Double = 0.5
    private let threeFingerContactMovementTolerance: Double = 8
    private let threeFingerSwipeThreshold: Double = 52
    private let threeFingerSwipeAxisDominance: Double = 1.35

    public init(
        timestampProvider: @escaping () -> UInt64 = TouchSurfaceEventMapper.defaultTimestampNanos,
        gestureConfiguration: TouchGestureConfiguration = TouchGestureConfiguration()
    ) {
        self.timestampProvider = timestampProvider
        self.gestureConfiguration = gestureConfiguration
    }

    public mutating func begin(at point: TouchPoint) -> InputEvent? {
        begin(with: [TouchContact(id: 0, point: point)]).first
    }

    public mutating func begin(with contacts: [TouchContact]) -> [InputEvent] {
        if var state = gestureState,
           state.kind == .threeFingerSwipe,
           !contacts.isEmpty {
            updateThreeFingerContacts(&state, with: contacts)
            gestureState = state
            return []
        }

        guard let state = makeGestureState(from: contacts) else {
            gestureState = nil
            return []
        }

        gestureState = state
        return []
    }

    public mutating func move(with contacts: [TouchContact]) -> [InputEvent] {
        guard var state = gestureState else {
            gestureState = makeGestureState(from: contacts)
            return []
        }
        if state.kind == .twoFinger && contacts.count < 2 {
            return []
        }
        if state.kind == .threeFingerSwipe && contacts.isEmpty {
            return []
        }
        let candidatePoint = state.kind == .threeFingerSwipe
            ? averagePoint(from: contacts.map(\.point))
            : trackedPoint(for: contacts)
        guard let currentPoint = candidatePoint else {
            return []
        }

        let timestamp = timestampProvider()
        let dx = currentPoint.x - state.previousPoint.x
        let dy = currentPoint.y - state.previousPoint.y
        let distanceFromPreviousPoint = distance(dx: dx, dy: dy)
        state.previousPoint = currentPoint
        state.previousTimeNanos = timestamp
        state.maxDistanceFromStart = max(state.maxDistanceFromStart, distance(from: state.startPoint, to: currentPoint))

        var events: [InputEvent] = []
        switch state.kind {
        case .singleFinger:
            if !state.isTapDragCandidate && !state.hasProcessedSingleFingerMove {
                state.hasProcessedSingleFingerMove = true
                if distanceFromPreviousPoint > firstPointerMoveRebaseTolerance {
                    state.suppressSingleFingerTap = true
                    gestureState = state
                    return []
                }
            }

            if state.isTapDragCandidate && !state.hasProcessedSingleFingerMove {
                state.hasProcessedSingleFingerMove = true
                if !state.isDragging {
                    state.isDragging = true
                    events.append(makeEvent(timestampNanos: timestamp, kind: .pointerButton(PointerButtonEvent(button: .left, phase: .down))))
                }

                if distanceFromPreviousPoint > tapDragFirstMoveRebaseTolerance {
                    gestureState = state
                    return events
                }
            }

            if state.isTapDragCandidate && !state.isDragging {
                state.isDragging = true
                events.append(makeEvent(timestampNanos: timestamp, kind: .pointerButton(PointerButtonEvent(button: .left, phase: .down))))
            }

            events.append(makeEvent(
                timestampNanos: timestamp,
                kind: .pointerMove(PointerMoveEvent(dx: dx, dy: dy))
            ))
        case .twoFinger:
            guard abs(dx) > scrollMovementTolerance || abs(dy) > scrollMovementTolerance else {
                gestureState = state
                return []
            }

            let phase: ScrollPhase = state.didScroll ? .changed : .began
            state.didScroll = true
            events.append(makeEvent(
                timestampNanos: timestamp,
                kind: .scroll(ScrollEvent(dx: dx, dy: dy, phase: phase))
            ))
        case .threeFingerSwipe:
            updateThreeFingerContacts(&state, with: contacts)
            let contactsMovingFromStart = threeFingerContactsMovingFromStart(in: state, contacts: contacts)
            let contactsMovingSincePrevious = threeFingerContactsMovingSincePrevious(in: state, contacts: contacts)

            if state.didEmitSystemAction {
                state.threeFingerPreviousContacts = contactMap(from: contacts)
                gestureState = state
                return []
            }

            if contactsMovingFromStart.count >= 2,
               let startPoint = threeFingerStartPoint(in: state, contacts: contacts),
               let action = threeFingerSwipeAction(from: startPoint, to: currentPoint) {
                state.didEmitSystemAction = true
                events.append(makeEvent(
                    timestampNanos: timestamp,
                    kind: .systemAction(SystemActionEvent(action: action))
                ))
            } else if contactsMovingFromStart.count < 2,
                      contactsMovingSincePrevious.count == 1,
                      let contact = contactsMovingSincePrevious.first,
                      let previousPoint = state.threeFingerPreviousContacts[contact.id] {
                events.append(makeEvent(
                    timestampNanos: timestamp,
                    kind: .pointerMove(PointerMoveEvent(
                        dx: contact.point.x - previousPoint.x,
                        dy: contact.point.y - previousPoint.y
                    ))
                ))
            }
            state.threeFingerPreviousContacts = contactMap(from: contacts)
        }

        gestureState = state
        return events
    }

    public mutating func end(with contacts: [TouchContact]) -> [InputEvent] {
        guard let state = gestureState else {
            gestureState = makeGestureState(from: contacts)
            return []
        }

        let shouldEndGesture: Bool
        switch state.kind {
        case .singleFinger:
            shouldEndGesture = contacts.isEmpty
        case .twoFinger:
            shouldEndGesture = contacts.count < 2
        case .threeFingerSwipe:
            shouldEndGesture = contacts.isEmpty
        }

        guard shouldEndGesture else {
            if var state = gestureState,
               state.kind == .threeFingerSwipe {
                updateThreeFingerContacts(&state, with: contacts)
                gestureState = state
            }
            return []
        }

        return finishGesture(state)
    }

    private mutating func finishGesture(_ state: GestureState) -> [InputEvent] {
        let timestamp = timestampProvider()
        var events: [InputEvent] = []
        switch state.kind {
        case .singleFinger:
            if state.isDragging {
                events.append(makeEvent(
                    timestampNanos: timestamp,
                    kind: .pointerButton(PointerButtonEvent(button: .left, phase: .up))
                ))
                lastSingleTapEndNanos = nil
            } else if state.suppressSingleFingerTap {
                lastSingleTapEndNanos = nil
            } else if timestamp - state.startTimeNanos <= gestureConfiguration.tapMaximumDurationNanos && state.maxDistanceFromStart <= tapMovementTolerance {
                events.append(makeEvent(
                    timestampNanos: timestamp,
                    kind: .tap(TapEvent(button: .left))
                ))
                lastSingleTapEndNanos = timestamp
            } else {
                lastSingleTapEndNanos = nil
            }
        case .twoFinger:
            lastSingleTapEndNanos = nil
            if state.didScroll {
                events.append(makeEvent(
                    timestampNanos: timestamp,
                    kind: .scroll(ScrollEvent(dx: 0, dy: 0, phase: .ended))
                ))
                suppressSingleFingerTapUntilNanos = timestamp + gestureConfiguration.scrollReleaseTapSuppressionNanos
            } else if !state.suppressSingleFingerTap && timestamp - state.startTimeNanos <= gestureConfiguration.tapMaximumDurationNanos && state.maxDistanceFromStart <= tapMovementTolerance {
                events.append(makeEvent(
                    timestampNanos: timestamp,
                    kind: .tap(TapEvent(button: .right))
                ))
            }
        case .threeFingerSwipe:
            lastSingleTapEndNanos = nil
            if state.didEmitSystemAction {
                suppressSingleFingerTapUntilNanos = timestamp + gestureConfiguration.scrollReleaseTapSuppressionNanos
                suppressTapUntilNanos = timestamp + gestureConfiguration.systemActionReleaseSuppressionNanos
            }
        }

        gestureState = nil
        return events
    }

    public mutating func move(to point: TouchPoint) -> InputEvent? {
        move(with: [TouchContact(id: 0, point: point)]).last
    }

    public mutating func end() {
        _ = end(with: [])
    }

    private mutating func makeEvent(timestampNanos: UInt64, kind: InputEventKind) -> InputEvent {
        let event = InputEvent(
            sequenceNumber: nextSequenceNumber,
            timestampNanos: timestampNanos,
            kind: kind
        )
        nextSequenceNumber += 1
        return event
    }

    private func makeGestureState(from contacts: [TouchContact]) -> GestureState? {
        guard let point = trackedPoint(for: contacts) else {
            return nil
        }

        let timestamp = timestampProvider()
        switch contacts.count {
        case 1:
            let shouldSuppressSingleTap = isSingleFingerTapSuppressed(at: timestamp) || isTapSuppressed(at: timestamp)
            return GestureState(
                kind: .singleFinger,
                startTimeNanos: timestamp,
                startPoint: point,
                previousPoint: point,
                previousTimeNanos: timestamp,
                isTapDragCandidate: !shouldSuppressSingleTap && isWithinTapDragInterval(timestamp),
                suppressSingleFingerTap: shouldSuppressSingleTap
            )
        case 2:
            return GestureState(
                kind: .twoFinger,
                startTimeNanos: timestamp,
                startPoint: point,
                previousPoint: point,
                previousTimeNanos: timestamp,
                suppressSingleFingerTap: isTapSuppressed(at: timestamp)
            )
        case 3:
            return GestureState(
                kind: .threeFingerSwipe,
                startTimeNanos: timestamp,
                startPoint: point,
                previousPoint: point,
                previousTimeNanos: timestamp,
                threeFingerStartContacts: contactMap(from: contacts),
                threeFingerPreviousContacts: contactMap(from: contacts)
            )
        default:
            return nil
        }
    }

    private func threeFingerSwipeAction(from start: TouchPoint, to current: TouchPoint) -> SystemAction? {
        let dx = current.x - start.x
        let dy = current.y - start.y
        let absX = abs(dx)
        let absY = abs(dy)

        if absY >= threeFingerSwipeThreshold && absY >= absX * threeFingerSwipeAxisDominance {
            return dy < 0 ? .missionControl : .appExpose
        }

        if absX >= threeFingerSwipeThreshold && absX >= absY * threeFingerSwipeAxisDominance {
            return dx < 0 ? .nextSpace : .previousSpace
        }

        return nil
    }

    private func threeFingerContactsMovingFromStart(in state: GestureState, contacts: [TouchContact]) -> [TouchContact] {
        contacts.filter { contact in
            guard let startPoint = state.threeFingerStartContacts[contact.id] else {
                return false
            }

            return distance(from: startPoint, to: contact.point) > threeFingerContactMovementTolerance
        }
    }

    private func threeFingerContactsMovingSincePrevious(in state: GestureState, contacts: [TouchContact]) -> [TouchContact] {
        contacts.filter { contact in
            guard let previousPoint = state.threeFingerPreviousContacts[contact.id] else {
                return false
            }

            return distance(from: previousPoint, to: contact.point) > scrollMovementTolerance
        }
    }

    private func threeFingerStartPoint(in state: GestureState, contacts: [TouchContact]) -> TouchPoint? {
        let startPoints = contacts.compactMap { state.threeFingerStartContacts[$0.id] }
        return averagePoint(from: startPoints)
    }

    private func updateThreeFingerContacts(_ state: inout GestureState, with contacts: [TouchContact]) {
        for contact in contacts where state.threeFingerStartContacts[contact.id] == nil {
            state.threeFingerStartContacts[contact.id] = contact.point
            state.threeFingerPreviousContacts[contact.id] = contact.point
        }
    }

    private func isSingleFingerTapSuppressed(at timestamp: UInt64) -> Bool {
        guard let suppressSingleFingerTapUntilNanos else {
            return false
        }

        return timestamp <= suppressSingleFingerTapUntilNanos
    }

    private func isTapSuppressed(at timestamp: UInt64) -> Bool {
        guard let suppressTapUntilNanos else {
            return false
        }

        return timestamp <= suppressTapUntilNanos
    }

    private func isWithinTapDragInterval(_ timestamp: UInt64) -> Bool {
        guard let lastSingleTapEndNanos else {
            return false
        }

        return timestamp >= lastSingleTapEndNanos && timestamp - lastSingleTapEndNanos <= gestureConfiguration.tapDragMaximumIntervalNanos
    }

    private func trackedPoint(for contacts: [TouchContact]) -> TouchPoint? {
        switch contacts.count {
        case 1:
            return contacts[0].point
        case 2:
            return averagePoint(from: contacts.map(\.point))
        case 3:
            return averagePoint(from: contacts.map(\.point))
        default:
            return nil
        }
    }

    private func averagePoint(from points: [TouchPoint]) -> TouchPoint? {
        guard !points.isEmpty else {
            return nil
        }

        let total = points.reduce((x: 0.0, y: 0.0)) { partial, point in
            (x: partial.x + point.x, y: partial.y + point.y)
        }
        let count = Double(points.count)
        return TouchPoint(x: total.x / count, y: total.y / count)
    }

    private func contactMap(from contacts: [TouchContact]) -> [Int: TouchPoint] {
        Dictionary(uniqueKeysWithValues: contacts.map { ($0.id, $0.point) })
    }

    private func distance(from start: TouchPoint, to end: TouchPoint) -> Double {
        let dx = end.x - start.x
        let dy = end.y - start.y
        return distance(dx: dx, dy: dy)
    }

    private func distance(dx: Double, dy: Double) -> Double {
        return (dx * dx + dy * dy).squareRoot()
    }

    public static func defaultTimestampNanos() -> UInt64 {
        UInt64(Date().timeIntervalSince1970 * 1_000_000_000)
    }
}
