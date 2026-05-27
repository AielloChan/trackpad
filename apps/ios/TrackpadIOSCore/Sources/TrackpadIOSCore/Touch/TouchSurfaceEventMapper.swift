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

public struct ScrollVelocity: Equatable, Sendable {
    public let dxPerSecond: Double
    public let dyPerSecond: Double

    public init(dxPerSecond: Double, dyPerSecond: Double) {
        self.dxPerSecond = dxPerSecond
        self.dyPerSecond = dyPerSecond
    }
}

public struct TouchGestureConfiguration: Equatable, Sendable {
    public let tapMaximumDurationNanos: UInt64
    public let tapDragMaximumIntervalNanos: UInt64
    public let scrollReleaseTapSuppressionNanos: UInt64

    public init(
        tapMaximumDurationMilliseconds: Double = 250,
        tapDragMaximumIntervalMilliseconds: Double = 140,
        scrollReleaseTapSuppressionMilliseconds: Double = 80
    ) {
        tapMaximumDurationNanos = Self.nanoseconds(from: tapMaximumDurationMilliseconds, range: 60...500)
        tapDragMaximumIntervalNanos = Self.nanoseconds(from: tapDragMaximumIntervalMilliseconds, range: 40...250)
        scrollReleaseTapSuppressionNanos = Self.nanoseconds(from: scrollReleaseTapSuppressionMilliseconds, range: 0...250)
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
        var suppressSingleFingerTap = false
        var didScroll = false
    }

    private var gestureState: GestureState?
    private var lastSingleTapEndNanos: UInt64?
    private var suppressSingleFingerTapUntilNanos: UInt64?
    public var gestureConfiguration: TouchGestureConfiguration
    public private(set) var lastScrollVelocity: ScrollVelocity?
    private var nextSequenceNumber: UInt64 = 1
    private let timestampProvider: () -> UInt64
    private let tapMovementTolerance: Double = 8
    private let scrollMovementTolerance: Double = 0.5

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
        guard let state = makeGestureState(from: contacts) else {
            gestureState = nil
            return []
        }

        gestureState = state
        return []
    }

    public mutating func move(with contacts: [TouchContact]) -> [InputEvent] {
        guard let currentPoint = trackedPoint(for: contacts) else {
            return []
        }

        guard var state = gestureState else {
            gestureState = makeGestureState(from: contacts)
            return []
        }

        let timestamp = timestampProvider()
        let dx = currentPoint.x - state.previousPoint.x
        let dy = currentPoint.y - state.previousPoint.y
        let previousTimeNanos = state.previousTimeNanos
        state.previousPoint = currentPoint
        state.previousTimeNanos = timestamp
        state.maxDistanceFromStart = max(state.maxDistanceFromStart, distance(from: state.startPoint, to: currentPoint))

        var events: [InputEvent] = []
        switch state.kind {
        case .singleFinger:
            if state.isTapDragCandidate && !state.isDragging && state.maxDistanceFromStart > tapMovementTolerance {
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
            updateScrollVelocity(dx: dx, dy: dy, from: previousTimeNanos, to: timestamp)
            events.append(makeEvent(
                timestampNanos: timestamp,
                kind: .scroll(ScrollEvent(dx: dx, dy: dy, phase: phase))
            ))
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
        }

        guard shouldEndGesture else {
            return []
        }

        return finishGesture(state)
    }

    public mutating func makeMomentumScrollEvent(dx: Double, dy: Double, phase: ScrollPhase = .changed) -> InputEvent {
        makeEvent(
            timestampNanos: timestampProvider(),
            kind: .scroll(ScrollEvent(dx: dx, dy: dy, phase: phase, momentumPhase: phase))
        )
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
            } else if timestamp - state.startTimeNanos <= gestureConfiguration.tapMaximumDurationNanos && state.maxDistanceFromStart <= tapMovementTolerance {
                events.append(makeEvent(
                    timestampNanos: timestamp,
                    kind: .tap(TapEvent(button: .right))
                ))
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
            let shouldSuppressSingleTap = isSingleFingerTapSuppressed(at: timestamp)
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
                previousTimeNanos: timestamp
            )
        default:
            return nil
        }
    }

    private func isSingleFingerTapSuppressed(at timestamp: UInt64) -> Bool {
        guard let suppressSingleFingerTapUntilNanos else {
            return false
        }

        return timestamp <= suppressSingleFingerTapUntilNanos
    }

    private func isWithinTapDragInterval(_ timestamp: UInt64) -> Bool {
        guard let lastSingleTapEndNanos else {
            return false
        }

        return timestamp >= lastSingleTapEndNanos && timestamp - lastSingleTapEndNanos <= gestureConfiguration.tapDragMaximumIntervalNanos
    }

    private mutating func updateScrollVelocity(dx: Double, dy: Double, from startNanos: UInt64, to endNanos: UInt64) {
        guard endNanos > startNanos else {
            return
        }

        let elapsedSeconds = Double(endNanos - startNanos) / 1_000_000_000
        guard elapsedSeconds > 0 else {
            return
        }

        lastScrollVelocity = ScrollVelocity(
            dxPerSecond: dx / elapsedSeconds,
            dyPerSecond: dy / elapsedSeconds
        )
    }

    private func trackedPoint(for contacts: [TouchContact]) -> TouchPoint? {
        switch contacts.count {
        case 1:
            return contacts[0].point
        case 2:
            return TouchPoint(
                x: (contacts[0].point.x + contacts[1].point.x) / 2,
                y: (contacts[0].point.y + contacts[1].point.y) / 2
            )
        default:
            return nil
        }
    }

    private func distance(from start: TouchPoint, to end: TouchPoint) -> Double {
        let dx = end.x - start.x
        let dy = end.y - start.y
        return (dx * dx + dy * dy).squareRoot()
    }

    public static func defaultTimestampNanos() -> UInt64 {
        UInt64(Date().timeIntervalSince1970 * 1_000_000_000)
    }
}

public struct ScrollMomentumStep: Equatable, Sendable {
    public let delayNanos: UInt64
    public let dx: Double
    public let dy: Double
    public let phase: ScrollPhase

    public init(delayNanos: UInt64, dx: Double, dy: Double, phase: ScrollPhase) {
        self.delayNanos = delayNanos
        self.dx = dx
        self.dy = dy
        self.phase = phase
    }
}

public struct ScrollMomentumPlanner: Sendable {
    private let frameIntervalNanos: UInt64
    private let decay: Double
    private let minimumDelta: Double
    private let maximumStepCount: Int

    public init(
        frameIntervalNanos: UInt64 = 16_000_000,
        decay: Double = 0.92,
        minimumDelta: Double = 0.6,
        maximumStepCount: Int = 72
    ) {
        self.frameIntervalNanos = frameIntervalNanos
        self.decay = decay
        self.minimumDelta = minimumDelta
        self.maximumStepCount = maximumStepCount
    }

    public func steps(initialDx: Double, initialDy: Double) -> [ScrollMomentumStep] {
        steps(initialDx: initialDx, initialDy: initialDy, applyInitialDecay: true)
    }

    public func steps(
        initialVelocityDxPerSecond: Double,
        initialVelocityDyPerSecond: Double,
        amount: Double = 1
    ) -> [ScrollMomentumStep] {
        let frameIntervalSeconds = Double(frameIntervalNanos) / 1_000_000_000
        let clampedAmount = min(max(amount, 0.2), 3)
        return steps(
            initialDx: initialVelocityDxPerSecond * frameIntervalSeconds * clampedAmount,
            initialDy: initialVelocityDyPerSecond * frameIntervalSeconds * clampedAmount,
            applyInitialDecay: false
        )
    }

    private func steps(initialDx: Double, initialDy: Double, applyInitialDecay: Bool) -> [ScrollMomentumStep] {
        var dx = initialDx * decay
        var dy = initialDy * decay
        if !applyInitialDecay {
            dx = initialDx
            dy = initialDy
        }
        guard abs(dx) >= minimumDelta || abs(dy) >= minimumDelta else {
            return []
        }

        var steps: [ScrollMomentumStep] = []
        for index in 1...maximumStepCount {
            guard abs(dx) >= minimumDelta || abs(dy) >= minimumDelta else {
                break
            }

            steps.append(ScrollMomentumStep(
                delayNanos: UInt64(index) * frameIntervalNanos,
                dx: dx,
                dy: dy,
                phase: .changed
            ))
            dx *= decay
            dy *= decay
        }

        steps.append(ScrollMomentumStep(
            delayNanos: UInt64(steps.count + 1) * frameIntervalNanos,
            dx: 0,
            dy: 0,
            phase: .ended
        ))
        return steps
    }
}
