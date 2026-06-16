import Foundation
#if SWIFT_PACKAGE
import TrackpadKit
#endif

struct PointerVelocitySample: Equatable, Sendable {
    let timestampNanos: UInt64
    let distance: Double
    let deltaSeconds: Double
}

public struct InputEventTuningState: Equatable, Sendable {
    var remainingLimitedDragStartupMoves: Int
    var remainingLimitedPointerStartupMoves: Int
    var lastPointerMoveTimestampNanos: UInt64?
    var pointerVelocitySamples: [PointerVelocitySample]

    public init(
        remainingLimitedDragStartupMoves: Int = 0,
        remainingLimitedPointerStartupMoves: Int = 0,
        lastPointerMoveTimestampNanos: UInt64? = nil
    ) {
        self.remainingLimitedDragStartupMoves = remainingLimitedDragStartupMoves
        self.remainingLimitedPointerStartupMoves = remainingLimitedPointerStartupMoves
        self.lastPointerMoveTimestampNanos = lastPointerMoveTimestampNanos
        pointerVelocitySamples = []
    }

    mutating func resetPointerVelocity() {
        lastPointerMoveTimestampNanos = nil
        pointerVelocitySamples.removeAll(keepingCapacity: true)
    }
}

public struct InputEventTuning: Equatable, Sendable {
    public let pointerSpeedMultiplier: Double
    public let pointerAccelerationMaximumMultiplier: Double
    public let pointerAccelerationStartVelocity: Double
    public let pointerAccelerationEndVelocity: Double
    private let maximumDragStartupMoveDelta: Double = 3
    private let limitedDragStartupMoveCount = 3
    private let limitedPointerStartupMoveCount = 1
    private let minimumUsefulPointerDeltaSeconds: Double = 0.001
    private let assumedPointerDeltaSeconds: Double = 1.0 / 60.0
    private let pointerVelocityWindowSeconds: Double = 0.08
    private let pointerVelocityResetSeconds: Double = 0.12

    public init(pointerSpeedMultiplier: Double) {
        self.init(
            pointerConfiguration: PointerConfiguration(speedMultiplier: pointerSpeedMultiplier)
        )
    }

    public init(pointerConfiguration: PointerConfiguration) {
        pointerSpeedMultiplier = min(max(pointerConfiguration.speedMultiplier, 0.2), 10)
        pointerAccelerationMaximumMultiplier = min(max(pointerConfiguration.accelerationMaximumMultiplier, 0.2), 10)
        pointerAccelerationStartVelocity = min(max(pointerConfiguration.accelerationStartVelocity, 0), 2_000)
        pointerAccelerationEndVelocity = min(max(pointerConfiguration.accelerationEndVelocity, 50), 5_000)
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
                state.resetPointerVelocity()
                return event
            }

            if case .pointerButton(let button) = event.kind,
               button.button == .left,
               button.phase == .up {
                state.remainingLimitedDragStartupMoves = 0
                state.resetPointerVelocity()
                return event
            }

            if case .contact(let contact) = event.kind,
               contact.phase == .began {
                state.remainingLimitedPointerStartupMoves = limitedPointerStartupMoveCount
                state.resetPointerVelocity()
                return event
            }

            let tunedEvent = apply(to: event, state: &state)
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
        var state = InputEventTuningState()
        return apply(to: event, state: &state)
    }

    private func apply(to event: InputEvent, state: inout InputEventTuningState) -> InputEvent {
        guard case .pointerMove(let move) = event.kind else {
            return event
        }

        let multiplier = pointerMultiplier(for: event, move: move, state: &state)
        return InputEvent(
            version: event.version,
            sequenceNumber: event.sequenceNumber,
            timestampNanos: event.timestampNanos,
            kind: .pointerMove(PointerMoveEvent(
                dx: move.dx * multiplier,
                dy: move.dy * multiplier
            ))
        )
    }

    private func pointerMultiplier(
        for event: InputEvent,
        move: PointerMoveEvent,
        state: inout InputEventTuningState
    ) -> Double {
        defer {
            state.lastPointerMoveTimestampNanos = event.timestampNanos
        }

        guard pointerAccelerationMaximumMultiplier > pointerSpeedMultiplier else {
            state.pointerVelocitySamples.removeAll(keepingCapacity: true)
            return pointerSpeedMultiplier
        }

        guard let lastTimestamp = state.lastPointerMoveTimestampNanos,
              event.timestampNanos > lastTimestamp else {
            state.pointerVelocitySamples.removeAll(keepingCapacity: true)
            return pointerSpeedMultiplier
        }

        let rawDeltaSeconds = Double(event.timestampNanos - lastTimestamp) / 1_000_000_000
        guard rawDeltaSeconds <= pointerVelocityResetSeconds else {
            state.pointerVelocitySamples.removeAll(keepingCapacity: true)
            return pointerSpeedMultiplier
        }

        let deltaSeconds: Double
        if rawDeltaSeconds < minimumUsefulPointerDeltaSeconds {
            deltaSeconds = assumedPointerDeltaSeconds
        } else {
            deltaSeconds = rawDeltaSeconds
        }
        let distance = hypot(move.dx, move.dy)
        state.pointerVelocitySamples.append(PointerVelocitySample(
            timestampNanos: event.timestampNanos,
            distance: distance,
            deltaSeconds: deltaSeconds
        ))
        let windowStartNanos = event.timestampNanos > UInt64(pointerVelocityWindowSeconds * 1_000_000_000)
            ? event.timestampNanos - UInt64(pointerVelocityWindowSeconds * 1_000_000_000)
            : 0
        state.pointerVelocitySamples.removeAll { sample in
            sample.timestampNanos < windowStartNanos
        }

        let windowDistance = state.pointerVelocitySamples.reduce(0) { total, sample in
            total + sample.distance
        }
        let windowSeconds = state.pointerVelocitySamples.reduce(0) { total, sample in
            total + sample.deltaSeconds
        }
        let windowVelocity = windowDistance / max(windowSeconds, minimumUsefulPointerDeltaSeconds)

        return pointerMultiplier(forVelocity: windowVelocity)
    }

    private func pointerMultiplier(forVelocity velocity: Double) -> Double {
        let startVelocity = min(pointerAccelerationStartVelocity, pointerAccelerationEndVelocity - 1)
        let endVelocity = max(pointerAccelerationEndVelocity, startVelocity + 1)
        let progress = min(max((velocity - startVelocity) / (endVelocity - startVelocity), 0), 1)
        let easedProgress = progress * progress * (3 - 2 * progress)
        return pointerSpeedMultiplier
            + (pointerAccelerationMaximumMultiplier - pointerSpeedMultiplier) * easedProgress
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
