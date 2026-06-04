import Foundation
import CoreGraphics
import TrackpadKit

public struct MacScrollMomentumSynthesizer: Sendable {
    private enum Axis {
        case horizontal
        case vertical
    }

    private struct ScrollSample: Sendable {
        let timestampNanos: UInt64
        let dx: Double
        let dy: Double
    }

    private struct MomentumState: Sendable {
        let axis: Axis
        let initialVelocity: Double
        let timeConstantSeconds: Double
        var startTimeNanos: UInt64
        let maximumDurationNanos: UInt64
        var previousTimeNanos: UInt64
        var didEmitMomentum = false
        var didEmitEnd = false
    }

    public private(set) var settings: ScrollMomentumSettings
    public let maximumInitialDelta: Double
    public let minimumInitialDelta: Double
    public let minimumStepDelta: Double
    public let maximumStepCount: Int
    public let frameIntervalNanos: UInt64

    private var samples: [ScrollSample] = []
    private var momentumState: MomentumState?

    private static let baseFrameIntervalNanos: UInt64 = 16_666_667
    private let axisDominance = 1.2
    private let minimumSampleDelta = 0.5

    public static func preferredFrameIntervalNanos() -> UInt64 {
        let refreshRate = CGDisplayCopyDisplayMode(CGMainDisplayID())?.refreshRate ?? 0
        guard refreshRate >= 30 else {
            return baseFrameIntervalNanos
        }

        return UInt64((1_000_000_000 / refreshRate).rounded())
    }

    public init(
        settings: ScrollMomentumSettings = TrackpadConfiguration.defaults.scrollMomentum,
        maximumInitialDelta: Double = 80,
        minimumInitialDelta: Double = 1.2,
        minimumStepDelta: Double = 0.2,
        maximumStepCount: Int = 180,
        frameIntervalNanos: UInt64 = MacScrollMomentumSynthesizer.preferredFrameIntervalNanos()
    ) {
        self.settings = settings
        self.maximumInitialDelta = maximumInitialDelta
        self.minimumInitialDelta = minimumInitialDelta
        self.minimumStepDelta = minimumStepDelta
        self.maximumStepCount = maximumStepCount
        self.frameIntervalNanos = frameIntervalNanos
    }

    public mutating func updateSettings(_ settings: ScrollMomentumSettings) {
        self.settings = settings
    }

    public mutating func reset() {
        resetSamples()
        momentumState = nil
    }

    public mutating func handle(_ event: InputEvent) -> Bool {
        guard case .scroll(let scroll) = event.kind else {
            reset()
            return false
        }

        guard scroll.momentumPhase == nil else {
            return false
        }

        switch scroll.phase {
        case .began:
            reset()
            appendSample(scroll, timestampNanos: event.timestampNanos)
            return false
        case .changed:
            momentumState = nil
            appendSample(scroll, timestampNanos: event.timestampNanos)
            return false
        case .ended:
            appendSample(scroll, timestampNanos: event.timestampNanos)
            let didStartMomentum = startMomentum(endingAt: event.timestampNanos)
            resetSamples()
            return didStartMomentum
        }
    }

    public mutating func cancelMomentum() {
        momentumState = nil
    }

    public mutating func startMomentumClock(at timestampNanos: UInt64) {
        guard var state = momentumState else {
            return
        }

        state.startTimeNanos = timestampNanos
        state.previousTimeNanos = timestampNanos
        momentumState = state
    }

    public mutating func nextMomentumCommand(at timestampNanos: UInt64) -> MacInputCommand? {
        guard var state = momentumState else {
            return nil
        }

        guard timestampNanos > state.previousTimeNanos else {
            return nil
        }

        let elapsedNanos = timestampNanos > state.startTimeNanos ? timestampNanos - state.startTimeNanos : 0
        let previousElapsedNanos = state.previousTimeNanos > state.startTimeNanos ? state.previousTimeNanos - state.startTimeNanos : 0
        let velocityAtFrame = velocity(from: state, elapsedNanos: elapsedNanos)
        let effectiveMinimumVelocity = minimumStepDelta / seconds(from: Self.baseFrameIntervalNanos)
        let shouldEnd = elapsedNanos >= state.maximumDurationNanos || abs(velocityAtFrame) < effectiveMinimumVelocity

        if shouldEnd {
            momentumState = nil
            return .scroll(dx: 0, dy: 0, phase: .ended, momentumPhase: .ended)
        }

        let delta = integratedDelta(from: state, previousElapsedNanos: previousElapsedNanos, elapsedNanos: elapsedNanos)
        state.previousTimeNanos = timestampNanos
        let momentumPhase: ScrollPhase = state.didEmitMomentum ? .changed : .began
        state.didEmitMomentum = true
        momentumState = state
        return scrollCommand(axis: state.axis, delta: delta, momentumPhase: momentumPhase)
    }

    private mutating func appendSample(_ scroll: ScrollEvent, timestampNanos: UInt64) {
        guard abs(scroll.dx) >= minimumSampleDelta || abs(scroll.dy) >= minimumSampleDelta else {
            return
        }

        samples.append(
            ScrollSample(
                timestampNanos: timestampNanos,
                dx: scroll.dx,
                dy: scroll.dy
            )
        )

        if samples.count > 16 {
            samples.removeFirst(samples.count - 16)
        }
    }

    private mutating func resetSamples() {
        samples.removeAll(keepingCapacity: true)
    }

    private mutating func startMomentum(endingAt timestampNanos: UInt64) -> Bool {
        guard !samples.isEmpty else {
            return false
        }

        guard settings.isEnabled else {
            return false
        }

        let amount = settings.amount.clamped(to: TrackpadConfigurationLimits.scrollMomentumAmount)
        guard amount > 0 else {
            return false
        }

        let decayRate = settings.decayRate.clamped(to: TrackpadConfigurationLimits.scrollMomentumDecayRate)
        let tailWindowNanos = UInt64((settings.tailWindowMilliseconds.clamped(to: TrackpadConfigurationLimits.scrollMomentumTailWindowMilliseconds) * 1_000_000).rounded())
        let windowStart = timestampNanos > tailWindowNanos ? timestampNanos - tailWindowNanos : 0
        let windowSamples = samples.filter { sample in
            sample.timestampNanos >= windowStart && sample.timestampNanos <= timestampNanos
        }

        guard !windowSamples.isEmpty,
              let axis = dominantAxis(in: windowSamples),
              let initialVelocity = initialVelocity(for: axis, samples: windowSamples, amount: amount) else {
            return false
        }

        guard let timeConstantSeconds = timeConstantSeconds(decayRate: decayRate) else {
            return false
        }

        momentumState = MomentumState(
            axis: axis,
            initialVelocity: initialVelocity,
            timeConstantSeconds: timeConstantSeconds,
            startTimeNanos: timestampNanos,
            maximumDurationNanos: UInt64(maximumStepCount) * Self.baseFrameIntervalNanos,
            previousTimeNanos: timestampNanos
        )
        return true
    }

    private func timeConstantSeconds(decayRate: Double) -> Double? {
        guard decayRate > 0, decayRate < 1 else {
            return nil
        }

        return -seconds(from: Self.baseFrameIntervalNanos) / log(decayRate)
    }

    private func velocity(from state: MomentumState, elapsedNanos: UInt64) -> Double {
        state.initialVelocity * exp(-seconds(from: elapsedNanos) / state.timeConstantSeconds)
    }

    private func integratedDelta(from state: MomentumState, previousElapsedNanos: UInt64, elapsedNanos: UInt64) -> Double {
        let previousElapsed = seconds(from: previousElapsedNanos)
        let elapsed = seconds(from: elapsedNanos)
        return state.initialVelocity
            * state.timeConstantSeconds
            * (exp(-previousElapsed / state.timeConstantSeconds) - exp(-elapsed / state.timeConstantSeconds))
    }

    private func dominantAxis(in samples: [ScrollSample]) -> Axis? {
        let horizontalMagnitude = samples.reduce(0) { $0 + abs($1.dx) }
        let verticalMagnitude = samples.reduce(0) { $0 + abs($1.dy) }

        guard horizontalMagnitude >= minimumSampleDelta || verticalMagnitude >= minimumSampleDelta else {
            return nil
        }

        if horizontalMagnitude > verticalMagnitude * axisDominance {
            return .horizontal
        }

        if verticalMagnitude > horizontalMagnitude * axisDominance {
            return .vertical
        }

        return verticalMagnitude >= horizontalMagnitude ? .vertical : .horizontal
    }

    private func initialVelocity(
        for axis: Axis,
        samples: [ScrollSample],
        amount: Double
    ) -> Double? {
        let deltas = samples
            .map { axis == .horizontal ? $0.dx : $0.dy }
            .filter { abs($0) >= minimumSampleDelta }

        guard !deltas.isEmpty else {
            return nil
        }

        let signedTotal = deltas.reduce(0, +)
        guard signedTotal != 0 else {
            return nil
        }

        let dominantSign = signedTotal > 0 ? 1.0 : -1.0
        let stableTotal = deltas
            .filter { $0.sign == FloatingPointSign.plus ? dominantSign > 0 : dominantSign < 0 }
            .reduce(0, +)

        guard abs(stableTotal) >= minimumSampleDelta else {
            return nil
        }

        guard let firstTimestamp = samples.first?.timestampNanos,
              let lastTimestamp = samples.last?.timestampNanos,
              lastTimestamp >= firstTimestamp else {
            return nil
        }

        let sampleSpanNanos = max(lastTimestamp - firstTimestamp + Self.baseFrameIntervalNanos, Self.baseFrameIntervalNanos)
        let averageBaseFrameDelta = stableTotal / Double(sampleSpanNanos) * Double(Self.baseFrameIntervalNanos)
        let scaledDelta = averageBaseFrameDelta * amount
        guard abs(scaledDelta) >= minimumInitialDelta else {
            return nil
        }

        let clampedFrameDelta = scaledDelta.clampedMagnitude(to: maximumInitialDelta)
        return clampedFrameDelta / seconds(from: Self.baseFrameIntervalNanos)
    }

    private func scrollCommand(axis: Axis, delta: Double, momentumPhase: ScrollPhase) -> MacInputCommand {
        switch axis {
        case .horizontal:
            return .scroll(dx: delta, dy: 0, phase: .changed, momentumPhase: momentumPhase)
        case .vertical:
            return .scroll(dx: 0, dy: delta, phase: .changed, momentumPhase: momentumPhase)
        }
    }
}

private func seconds(from nanoseconds: UInt64) -> Double {
    Double(nanoseconds) / 1_000_000_000
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }

    func clampedMagnitude(to maximumMagnitude: Double) -> Double {
        guard abs(self) > maximumMagnitude else {
            return self
        }

        return self > 0 ? maximumMagnitude : -maximumMagnitude
    }
}
