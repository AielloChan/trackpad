import Testing
import TrackpadKit
@testable import TrackpadHostCore

@Test func macScrollMomentumSynthesizerBuildsMomentumAfterFingerScrollEnds() {
    var synthesizer = MacScrollMomentumSynthesizer(
        settings: ScrollMomentumSettings(amount: 1, decayRate: 0.8, tailWindowMilliseconds: 120),
        minimumStepDelta: 6,
        maximumStepCount: 8,
        frameIntervalNanos: 16_666_667
    )

    #expect(synthesizer.commands(after: scrollEvent(sequence: 1, timestamp: 0, dx: 0, dy: 20, phase: .began)).isEmpty)
    #expect(synthesizer.commands(after: scrollEvent(sequence: 2, timestamp: 110_000_000, dx: 0, dy: 40, phase: .changed)).isEmpty)

    let commands = synthesizer.commands(after: scrollEvent(sequence: 3, timestamp: 120_000_000, dx: 0, dy: 0, phase: .ended))

    #expect(commands.count == 3)
    #expect(commands[0].isScroll(dx: 0, dy: 8.3333335, phase: .changed, momentumPhase: .began))
    #expect(commands[1].isScroll(dx: 0, dy: 6.6666668, phase: .changed, momentumPhase: .changed))
    #expect(commands[2] == .scroll(dx: 0, dy: 0, phase: .ended, momentumPhase: .ended))
}

@Test func macScrollMomentumSynthesizerIgnoresClientMomentumEvents() {
    var synthesizer = MacScrollMomentumSynthesizer()
    let event = scrollEvent(
        sequence: 1,
        timestamp: 0,
        dx: 0,
        dy: 10,
        phase: .changed,
        momentumPhase: .began
    )

    #expect(synthesizer.commands(after: event).isEmpty)
}

@Test func macScrollMomentumSynthesizerSupportsLongerNativeLikeMomentumTuning() {
    var synthesizer = MacScrollMomentumSynthesizer(
        settings: ScrollMomentumSettings(amount: 6, decayRate: 0.99, tailWindowMilliseconds: 300),
        frameIntervalNanos: 16_666_667
    )

    #expect(synthesizer.commands(after: scrollEvent(sequence: 1, timestamp: 0, dx: 0, dy: 18, phase: .began)).isEmpty)
    #expect(synthesizer.commands(after: scrollEvent(sequence: 2, timestamp: 16_666_667, dx: 0, dy: 20, phase: .changed)).isEmpty)
    #expect(synthesizer.commands(after: scrollEvent(sequence: 3, timestamp: 33_333_334, dx: 0, dy: 22, phase: .changed)).isEmpty)
    #expect(synthesizer.commands(after: scrollEvent(sequence: 4, timestamp: 50_000_001, dx: 0, dy: 24, phase: .changed)).isEmpty)

    let commands = synthesizer.commands(after: scrollEvent(sequence: 5, timestamp: 66_666_668, dx: 0, dy: 0, phase: .ended))

    #expect(commands.count > 50)
    #expect(commands.last == .scroll(dx: 0, dy: 0, phase: .ended, momentumPhase: .ended))
}

@Test func macScrollMomentumSynthesizerKeepsDistanceStableAtHigherRefreshRates() {
    var sixtyHertzSynthesizer = MacScrollMomentumSynthesizer(
        settings: ScrollMomentumSettings(amount: 5, decayRate: 0.95, tailWindowMilliseconds: 140),
        frameIntervalNanos: 16_666_667
    )
    var oneTwentyHertzSynthesizer = MacScrollMomentumSynthesizer(
        settings: ScrollMomentumSettings(amount: 5, decayRate: 0.95, tailWindowMilliseconds: 140),
        frameIntervalNanos: 8_333_333
    )

    let inputEvents = [
        scrollEvent(sequence: 1, timestamp: 0, dx: 0, dy: 24, phase: .began),
        scrollEvent(sequence: 2, timestamp: 16_666_667, dx: 0, dy: 24, phase: .changed),
        scrollEvent(sequence: 3, timestamp: 33_333_334, dx: 0, dy: 24, phase: .changed),
        scrollEvent(sequence: 4, timestamp: 50_000_001, dx: 0, dy: 0, phase: .ended),
    ]

    let sixtyHertzCommands = commands(from: inputEvents, using: &sixtyHertzSynthesizer)
    let oneTwentyHertzCommands = commands(from: inputEvents, using: &oneTwentyHertzSynthesizer)

    #expect(oneTwentyHertzCommands.count > sixtyHertzCommands.count)
    #expect(abs(oneTwentyHertzCommands.totalScrollDistance - sixtyHertzCommands.totalScrollDistance) < 5)
}

private func scrollEvent(
    sequence: UInt64,
    timestamp: UInt64,
    dx: Double,
    dy: Double,
    phase: ScrollPhase,
    momentumPhase: ScrollPhase? = nil
) -> InputEvent {
    InputEvent(
        sequenceNumber: sequence,
        timestampNanos: timestamp,
        kind: .scroll(ScrollEvent(dx: dx, dy: dy, phase: phase, momentumPhase: momentumPhase))
    )
}

private func commands(
    from events: [InputEvent],
    using synthesizer: inout MacScrollMomentumSynthesizer
) -> [MacInputCommand] {
    events.flatMap { synthesizer.commands(after: $0) }
}

private extension Array where Element == MacInputCommand {
    var totalScrollDistance: Double {
        reduce(0) { total, command in
            guard case .scroll(let dx, let dy, .changed, _) = command else {
                return total
            }

            return total + abs(dx) + abs(dy)
        }
    }
}

private extension MacInputCommand {
    func isScroll(
        dx expectedDx: Double,
        dy expectedDy: Double,
        phase expectedPhase: ScrollPhase,
        momentumPhase expectedMomentumPhase: ScrollPhase
    ) -> Bool {
        guard case .scroll(let dx, let dy, let phase, let momentumPhase) = self else {
            return false
        }

        return abs(dx - expectedDx) < 0.0001
            && abs(dy - expectedDy) < 0.0001
            && phase == expectedPhase
            && momentumPhase == expectedMomentumPhase
    }
}
