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

    public private(set) var settings: ScrollMomentumSettings
    public let maximumInitialDelta: Double
    public let minimumInitialDelta: Double
    public let minimumStepDelta: Double
    public let maximumStepCount: Int
    public let frameIntervalNanos: UInt64

    private var samples: [ScrollSample] = []

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
        samples.removeAll(keepingCapacity: true)
    }

    public mutating func commands(after event: InputEvent) -> [MacInputCommand] {
        guard case .scroll(let scroll) = event.kind else {
            reset()
            return []
        }

        guard scroll.momentumPhase == nil else {
            return []
        }

        switch scroll.phase {
        case .began:
            reset()
            appendSample(scroll, timestampNanos: event.timestampNanos)
            return []
        case .changed:
            appendSample(scroll, timestampNanos: event.timestampNanos)
            return []
        case .ended:
            appendSample(scroll, timestampNanos: event.timestampNanos)
            let commands = buildMomentumCommands(endingAt: event.timestampNanos)
            reset()
            return commands
        }
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

    private func buildMomentumCommands(endingAt timestampNanos: UInt64) -> [MacInputCommand] {
        guard !samples.isEmpty else {
            return []
        }

        let amount = settings.amount.clamped(to: TrackpadConfigurationLimits.scrollMomentumAmount)
        guard amount > 0 else {
            return []
        }

        let decayRate = settings.decayRate.clamped(to: TrackpadConfigurationLimits.scrollMomentumDecayRate)
        let tailWindowNanos = UInt64((settings.tailWindowMilliseconds.clamped(to: TrackpadConfigurationLimits.scrollMomentumTailWindowMilliseconds) * 1_000_000).rounded())
        let windowStart = timestampNanos > tailWindowNanos ? timestampNanos - tailWindowNanos : 0
        let windowSamples = samples.filter { sample in
            sample.timestampNanos >= windowStart && sample.timestampNanos <= timestampNanos
        }

        guard !windowSamples.isEmpty,
              let axis = dominantAxis(in: windowSamples),
              let initialDelta = initialDelta(for: axis, samples: windowSamples, tailWindowNanos: tailWindowNanos, amount: amount) else {
            return []
        }

        let frameScale = Double(frameIntervalNanos) / Double(Self.baseFrameIntervalNanos)
        let perFrameDecayRate = pow(decayRate, frameScale)
        var current = initialDelta * distanceCompensation(decayRate: decayRate, perFrameDecayRate: perFrameDecayRate, frameScale: frameScale)
        var momentumPhase = ScrollPhase.began
        var commands: [MacInputCommand] = []
        let effectiveMinimumStepDelta = minimumStepDelta * frameScale
        let effectiveMaximumStepCount = max(1, Int((Double(maximumStepCount) / frameScale).rounded(.up)))

        while abs(current) >= effectiveMinimumStepDelta && commands.count < effectiveMaximumStepCount {
            commands.append(scrollCommand(axis: axis, delta: current, momentumPhase: momentumPhase))
            current *= perFrameDecayRate
            momentumPhase = .changed
        }

        guard !commands.isEmpty else {
            return []
        }

        commands.append(.scroll(dx: 0, dy: 0, phase: .ended, momentumPhase: .ended))
        return commands
    }

    private func distanceCompensation(decayRate: Double, perFrameDecayRate: Double, frameScale: Double) -> Double {
        guard frameScale > 0, decayRate < 1 else {
            return 1
        }

        return (1 - perFrameDecayRate) / (frameScale * (1 - decayRate))
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

    private func initialDelta(
        for axis: Axis,
        samples: [ScrollSample],
        tailWindowNanos: UInt64,
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

        let averageFrameDelta = stableTotal / Double(tailWindowNanos) * Double(frameIntervalNanos)
        let scaledDelta = averageFrameDelta * amount
        guard abs(scaledDelta) >= minimumInitialDelta else {
            return nil
        }

        return scaledDelta.clampedMagnitude(to: maximumInitialDelta)
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
