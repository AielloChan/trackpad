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
    public let surfaceWidth: Double?

    public init(id: Int, point: TouchPoint, surfaceWidth: Double? = nil) {
        self.id = id
        self.point = point
        self.surfaceWidth = surfaceWidth
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
        case rightEdgeNotificationCenter
        case notificationCenterCloseSwipe
        case launchpadPinch
    }

    private enum FourFingerInterfaceState {
        case normal
        case launchpad
        case desktop
    }

    private enum FourFingerPinchDirection {
        case inward
        case outward
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
        var didSeeSecondContact = false
        var threeFingerStartContacts: [Int: TouchPoint] = [:]
        var threeFingerPreviousContacts: [Int: TouchPoint] = [:]
        var rightEdgeStartContacts: [Int: TouchPoint] = [:]
        var launchpadPinchStartContacts: [Int: TouchPoint] = [:]
    }

    private struct PendingTap {
        var button: PointerButton
        var timestampNanos: UInt64
    }

    private var gestureState: GestureState?
    private var lastSingleTapEndNanos: UInt64?
    private var pendingTap: PendingTap?
    private var suppressSingleFingerTapUntilNanos: UInt64?
    private var suppressTapUntilNanos: UInt64?
    private var notificationCenterCloseSwipeArmed = false
    private var fourFingerInterfaceState: FourFingerInterfaceState = .normal
    public var gestureConfiguration: TouchGestureConfiguration
    private var nextSequenceNumber: UInt64 = 1
    private let timestampProvider: () -> UInt64
    private let tapMovementTolerance: Double = 8
    private let firstPointerMoveRebaseTolerance: Double = 3
    private let tapDragFirstMoveRebaseTolerance: Double = 8
    private let tapDragFirstMoveMaximumRebasedDelta: Double = 3
    private let scrollMovementTolerance: Double = 0.5
    private let threeFingerContactMovementTolerance: Double = 8
    private let threeFingerSwipeThreshold: Double = 52
    private let threeFingerSwipeAxisDominance: Double = 1.35
    private let rightEdgeGestureStartInset: Double = 24
    private let rightEdgeGestureSwipeThreshold: Double = 42
    private let rightEdgeGestureAxisDominance: Double = 1.2
    private let notificationCenterCloseSwipeThreshold: Double = 42
    private let notificationCenterCloseSwipeAxisDominance: Double = 1.2
    private let launchpadPinchAverageContractionThreshold: Double = 32
    private let launchpadPinchContactContractionThreshold: Double = 18
    private let launchpadPinchMinimumInwardContactCount = 3

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

    public mutating func contactBegan(with contacts: [TouchContact]) -> InputEvent? {
        guard !contacts.isEmpty else {
            return nil
        }

        return makeEvent(
            timestampNanos: timestampProvider(),
            kind: .contact(ContactEvent(phase: .began, contactCount: contacts.count))
        )
    }

    public mutating func begin(with contacts: [TouchContact]) -> [InputEvent] {
        if var state = gestureState,
           !contacts.isEmpty {
            let timestamp = timestampProvider()
            if shouldTransitionToLaunchpadPinch(from: state, contacts: contacts, timestamp: timestamp) {
                gestureState = makeLaunchpadPinchState(from: contacts, timestamp: timestamp, point: averagePoint(from: contacts.map(\.point)) ?? state.previousPoint)
                return []
            }
            if state.kind == .threeFingerSwipe {
                updateThreeFingerContacts(&state, with: contacts)
            }
            if state.kind == .rightEdgeNotificationCenter || shouldTransitionToRightEdgeNotificationCenter(from: state, contacts: contacts) {
                state.kind = .rightEdgeNotificationCenter
                updateRightEdgeContacts(&state, with: contacts)
                return handleRightEdgeNotificationCenterContacts(&state, contacts: contacts)
            }
            if state.kind == .threeFingerSwipe {
                gestureState = state
                return []
            }
        }

        let timestamp = timestampProvider()
        var events: [InputEvent] = []
        if !canCurrentContactsContinuePendingTapDrag(contacts, timestamp: timestamp) {
            events.append(contentsOf: flushPendingTap(clearTapDragAnchor: true))
        }

        guard let state = makeGestureState(from: contacts, timestamp: timestamp) else {
            gestureState = nil
            return events
        }

        gestureState = state
        return events
    }

    public mutating func move(with contacts: [TouchContact]) -> [InputEvent] {
        guard var state = gestureState else {
            gestureState = makeGestureState(from: contacts, timestamp: timestampProvider())
            return []
        }
        if state.kind == .twoFinger && contacts.count < 2 {
            return []
        }
        if state.kind == .threeFingerSwipe && contacts.isEmpty {
            return []
        }
        if state.kind == .rightEdgeNotificationCenter && contacts.isEmpty {
            return []
        }
        if state.kind == .notificationCenterCloseSwipe && contacts.count < 2 {
            return []
        }
        if state.kind == .launchpadPinch && contacts.isEmpty {
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
                    if let limitedMove = limitedFirstMove(dx: dx, dy: dy, maximumDelta: firstPointerMoveRebaseTolerance) {
                        events.append(makeEvent(timestampNanos: timestamp, kind: .pointerMove(limitedMove)))
                    }
                    gestureState = state
                    return events
                }
            }

            if state.isTapDragCandidate && !state.hasProcessedSingleFingerMove {
                state.hasProcessedSingleFingerMove = true
                if !state.isDragging {
                    state.isDragging = true
                    cancelPendingTap()
                    events.append(makeEvent(timestampNanos: timestamp, kind: .pointerButton(PointerButtonEvent(button: .left, phase: .down))))
                }

                if distanceFromPreviousPoint > tapDragFirstMoveRebaseTolerance {
                    if let limitedMove = limitedFirstMove(dx: dx, dy: dy, maximumDelta: tapDragFirstMoveMaximumRebasedDelta) {
                        events.append(makeEvent(timestampNanos: timestamp, kind: .pointerMove(limitedMove)))
                    }
                    gestureState = state
                    return events
                }
            }

            if state.isTapDragCandidate && !state.isDragging {
                state.isDragging = true
                cancelPendingTap()
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
        case .rightEdgeNotificationCenter:
            updateRightEdgeContacts(&state, with: contacts)
            if contacts.count >= 2 {
                state.didSeeSecondContact = true
            }

            guard !state.didEmitSystemAction else {
                gestureState = state
                return []
            }

            if state.didSeeSecondContact,
               hasRightEdgeNotificationCenterSwipe(in: state, contacts: contacts) {
                state.didEmitSystemAction = true
                events.append(makeEvent(
                    timestampNanos: timestamp,
                    kind: .systemAction(SystemActionEvent(action: .showNotificationCenter))
                ))
            }
        case .notificationCenterCloseSwipe:
            guard !state.didEmitSystemAction else {
                gestureState = state
                return []
            }

            if isNotificationCenterCloseSwipe(from: state.startPoint, to: currentPoint) {
                state.didEmitSystemAction = true
                notificationCenterCloseSwipeArmed = false
                events.append(makeEvent(
                    timestampNanos: timestamp,
                    kind: .systemAction(SystemActionEvent(action: .hideNotificationCenter))
                ))
            }
        case .launchpadPinch:
            guard !state.didEmitSystemAction else {
                gestureState = state
                return []
            }

            if let direction = fourFingerPinchDirection(in: state, contacts: contacts),
               let action = systemAction(for: direction) {
                state.didEmitSystemAction = true
                events.append(makeEvent(
                    timestampNanos: timestamp,
                    kind: .systemAction(SystemActionEvent(action: action))
                ))
            }
        }

        gestureState = state
        return events
    }

    public mutating func end(with contacts: [TouchContact]) -> [InputEvent] {
        guard let state = gestureState else {
            gestureState = makeGestureState(from: contacts, timestamp: timestampProvider())
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
        case .rightEdgeNotificationCenter:
            shouldEndGesture = contacts.isEmpty
        case .notificationCenterCloseSwipe:
            shouldEndGesture = contacts.count < 2
        case .launchpadPinch:
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
                if state.isTapDragCandidate {
                    events.append(contentsOf: flushPendingTap(clearTapDragAnchor: false))
                }
                pendingTap = PendingTap(button: .left, timestampNanos: timestamp)
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
        case .rightEdgeNotificationCenter:
            lastSingleTapEndNanos = nil
            if state.didEmitSystemAction {
                notificationCenterCloseSwipeArmed = true
                suppressSingleFingerTapUntilNanos = timestamp + gestureConfiguration.scrollReleaseTapSuppressionNanos
                suppressTapUntilNanos = timestamp + gestureConfiguration.systemActionReleaseSuppressionNanos
            }
        case .notificationCenterCloseSwipe:
            lastSingleTapEndNanos = nil
            if state.didEmitSystemAction {
                suppressSingleFingerTapUntilNanos = timestamp + gestureConfiguration.scrollReleaseTapSuppressionNanos
                suppressTapUntilNanos = timestamp + gestureConfiguration.systemActionReleaseSuppressionNanos
            }
        case .launchpadPinch:
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

    public mutating func flushExpiredPendingEvents() -> [InputEvent] {
        flushExpiredPendingEvents(at: timestampProvider())
    }

    public mutating func cancelPendingEvents() {
        cancelPendingTap()
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

    private func makeGestureState(from contacts: [TouchContact], timestamp: UInt64) -> GestureState? {
        guard let point = trackedPoint(for: contacts) else {
            return nil
        }

        switch contacts.count {
        case 1:
            let shouldSuppressSingleTap = isSingleFingerTapSuppressed(at: timestamp) || isTapSuppressed(at: timestamp)
            if isRightEdgeNotificationCenterCandidate(contacts[0]) {
                return GestureState(
                    kind: .rightEdgeNotificationCenter,
                    startTimeNanos: timestamp,
                    startPoint: point,
                    previousPoint: point,
                    previousTimeNanos: timestamp,
                    suppressSingleFingerTap: true,
                    rightEdgeStartContacts: contactMap(from: contacts)
                )
            }
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
            if let rightEdgeState = makeRightEdgeNotificationCenterState(from: contacts, timestamp: timestamp, point: point) {
                return rightEdgeState
            }
            if notificationCenterCloseSwipeArmed {
                return GestureState(
                    kind: .notificationCenterCloseSwipe,
                    startTimeNanos: timestamp,
                    startPoint: point,
                    previousPoint: point,
                    previousTimeNanos: timestamp,
                    suppressSingleFingerTap: true
                )
            }
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
        case 4:
            return makeLaunchpadPinchState(from: contacts, timestamp: timestamp, point: point)
        default:
            return nil
        }
    }

    private func canCurrentContactsContinuePendingTapDrag(_ contacts: [TouchContact], timestamp: UInt64) -> Bool {
        guard pendingTap != nil,
              contacts.count == 1,
              !isSingleFingerTapSuppressed(at: timestamp),
              !isTapSuppressed(at: timestamp) else {
            return false
        }

        return isWithinTapDragInterval(timestamp)
    }

    private mutating func flushExpiredPendingEvents(at timestamp: UInt64) -> [InputEvent] {
        guard let pendingTap,
              timestamp >= pendingTap.timestampNanos,
              timestamp - pendingTap.timestampNanos >= gestureConfiguration.tapDragMaximumIntervalNanos else {
            return []
        }

        return flushPendingTap(clearTapDragAnchor: true)
    }

    private mutating func flushPendingTap(clearTapDragAnchor: Bool) -> [InputEvent] {
        guard let pendingTap else {
            return []
        }

        self.pendingTap = nil
        if clearTapDragAnchor {
            lastSingleTapEndNanos = nil
        }
        return [
            makeEvent(
                timestampNanos: pendingTap.timestampNanos,
                kind: .tap(TapEvent(button: pendingTap.button))
            ),
        ]
    }

    private mutating func cancelPendingTap() {
        pendingTap = nil
        lastSingleTapEndNanos = nil
    }

    private func makeRightEdgeNotificationCenterState(from contacts: [TouchContact], timestamp: UInt64, point: TouchPoint) -> GestureState? {
        let rightEdgeContacts = contacts.filter(isRightEdgeNotificationCenterCandidate)
        guard !rightEdgeContacts.isEmpty else {
            return nil
        }

        return GestureState(
            kind: .rightEdgeNotificationCenter,
            startTimeNanos: timestamp,
            startPoint: point,
            previousPoint: point,
            previousTimeNanos: timestamp,
            suppressSingleFingerTap: true,
            didSeeSecondContact: contacts.count >= 2,
            rightEdgeStartContacts: contactMap(from: rightEdgeContacts)
        )
    }

    private func shouldTransitionToRightEdgeNotificationCenter(from state: GestureState, contacts: [TouchContact]) -> Bool {
        guard state.kind != .rightEdgeNotificationCenter,
              contacts.count >= 2 else {
            return false
        }

        return contacts.contains(where: isRightEdgeNotificationCenterCandidate)
    }

    private func shouldTransitionToLaunchpadPinch(from state: GestureState, contacts: [TouchContact], timestamp: UInt64) -> Bool {
        guard state.kind != .launchpadPinch,
              !state.didEmitSystemAction,
              contacts.count == 4,
              !isTapSuppressed(at: timestamp) else {
            return false
        }

        switch state.kind {
        case .singleFinger, .twoFinger, .threeFingerSwipe:
            return true
        case .rightEdgeNotificationCenter, .notificationCenterCloseSwipe, .launchpadPinch:
            return false
        }
    }

    private func makeLaunchpadPinchState(from contacts: [TouchContact], timestamp: UInt64, point: TouchPoint) -> GestureState {
        GestureState(
            kind: .launchpadPinch,
            startTimeNanos: timestamp,
            startPoint: point,
            previousPoint: point,
            previousTimeNanos: timestamp,
            suppressSingleFingerTap: true,
            launchpadPinchStartContacts: contactMap(from: contacts)
        )
    }

    private mutating func handleRightEdgeNotificationCenterContacts(_ state: inout GestureState, contacts: [TouchContact]) -> [InputEvent] {
        if contacts.count >= 2 {
            state.didSeeSecondContact = true
        }
        guard let currentPoint = trackedPoint(for: contacts) else {
            gestureState = state
            return []
        }

        let timestamp = timestampProvider()
        state.previousPoint = currentPoint
        state.previousTimeNanos = timestamp
        state.maxDistanceFromStart = max(state.maxDistanceFromStart, distance(from: state.startPoint, to: currentPoint))
        guard state.didSeeSecondContact,
              !state.didEmitSystemAction,
              hasRightEdgeNotificationCenterSwipe(in: state, contacts: contacts) else {
            gestureState = state
            return []
        }

        state.didEmitSystemAction = true
        gestureState = state
        return [
            makeEvent(
                timestampNanos: timestamp,
                kind: .systemAction(SystemActionEvent(action: .showNotificationCenter))
            ),
        ]
    }

    private func updateRightEdgeContacts(_ state: inout GestureState, with contacts: [TouchContact]) {
        for contact in contacts where state.rightEdgeStartContacts[contact.id] == nil && isRightEdgeNotificationCenterCandidate(contact) {
            state.rightEdgeStartContacts[contact.id] = contact.point
        }
    }

    private func isRightEdgeNotificationCenterCandidate(_ contact: TouchContact) -> Bool {
        guard let surfaceWidth = contact.surfaceWidth, surfaceWidth > 0 else {
            return false
        }

        return surfaceWidth - contact.point.x <= rightEdgeGestureStartInset
    }

    private func hasRightEdgeNotificationCenterSwipe(in state: GestureState, contacts: [TouchContact]) -> Bool {
        contacts.contains { contact in
            guard let start = state.rightEdgeStartContacts[contact.id] else {
                return false
            }

            return isRightEdgeNotificationCenterSwipe(from: start, to: contact.point)
        }
    }

    private func isRightEdgeNotificationCenterSwipe(from start: TouchPoint, to current: TouchPoint) -> Bool {
        let dx = current.x - start.x
        let dy = current.y - start.y
        let absX = abs(dx)
        let absY = abs(dy)

        return dx <= -rightEdgeGestureSwipeThreshold && absX >= absY * rightEdgeGestureAxisDominance
    }

    private func isNotificationCenterCloseSwipe(from start: TouchPoint, to current: TouchPoint) -> Bool {
        let dx = current.x - start.x
        let dy = current.y - start.y
        let absX = abs(dx)
        let absY = abs(dy)

        return dx >= notificationCenterCloseSwipeThreshold && absX >= absY * notificationCenterCloseSwipeAxisDominance
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

    private mutating func systemAction(for direction: FourFingerPinchDirection) -> SystemAction? {
        switch (fourFingerInterfaceState, direction) {
        case (.normal, .inward):
            fourFingerInterfaceState = .launchpad
            return .openLaunchpad
        case (.launchpad, .inward):
            return nil
        case (.desktop, .inward):
            fourFingerInterfaceState = .normal
            return .hideDesktop
        case (.normal, .outward):
            fourFingerInterfaceState = .desktop
            return .showDesktop
        case (.launchpad, .outward):
            fourFingerInterfaceState = .normal
            return .closeLaunchpad
        case (.desktop, .outward):
            return nil
        }
    }

    private func fourFingerPinchDirection(in state: GestureState, contacts: [TouchContact]) -> FourFingerPinchDirection? {
        guard contacts.count == 4,
              let startCenter = averagePoint(from: contacts.compactMap({ state.launchpadPinchStartContacts[$0.id] })),
              let currentCenter = averagePoint(from: contacts.map(\.point)) else {
            return nil
        }

        var totalContraction = 0.0
        var inwardContactCount = 0
        var outwardContactCount = 0
        var matchedContactCount = 0
        for contact in contacts {
            guard let start = state.launchpadPinchStartContacts[contact.id] else {
                continue
            }

            matchedContactCount += 1
            let contraction = distance(from: startCenter, to: start) - distance(from: currentCenter, to: contact.point)
            totalContraction += contraction
            if contraction >= launchpadPinchContactContractionThreshold {
                inwardContactCount += 1
            }
            if contraction <= -launchpadPinchContactContractionThreshold {
                outwardContactCount += 1
            }
        }
        guard matchedContactCount == 4 else {
            return nil
        }

        let averageContraction = totalContraction / Double(matchedContactCount)
        if averageContraction >= launchpadPinchAverageContractionThreshold,
           inwardContactCount >= launchpadPinchMinimumInwardContactCount {
            return .inward
        }
        if averageContraction <= -launchpadPinchAverageContractionThreshold,
           outwardContactCount >= launchpadPinchMinimumInwardContactCount {
            return .outward
        }
        return nil
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
        case 4:
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

    private func limitedFirstMove(dx: Double, dy: Double, maximumDelta: Double) -> PointerMoveEvent? {
        let limitedDx = clamped(dx, to: maximumDelta)
        let limitedDy = clamped(dy, to: maximumDelta)
        guard limitedDx != 0 || limitedDy != 0 else {
            return nil
        }

        return PointerMoveEvent(dx: limitedDx, dy: limitedDy)
    }

    private func clamped(_ value: Double, to limit: Double) -> Double {
        return min(max(value, -limit), limit)
    }

    public static func defaultTimestampNanos() -> UInt64 {
        UInt64(Date().timeIntervalSince1970 * 1_000_000_000)
    }
}
