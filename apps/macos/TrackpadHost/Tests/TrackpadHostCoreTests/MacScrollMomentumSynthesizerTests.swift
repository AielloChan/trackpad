import Testing
import TrackpadKit
@testable import TrackpadHostCore

@Test func macScrollMomentumSynthesizerBuildsMomentumAfterFingerScrollEnds() {
    var synthesizer = MacScrollMomentumSynthesizer(
        settings: ScrollMomentumSettings(amount: 1, decayRate: 0.8, tailWindowMilliseconds: 120),
        minimumStepDelta: 4,
        maximumStepCount: 8,
        frameIntervalNanos: 16_666_667
    )

    let beganStartedMomentum = synthesizer.handle(scrollEvent(sequence: 1, timestamp: 0, dx: 0, dy: 20, phase: .began))
    let changedStartedMomentum = synthesizer.handle(scrollEvent(sequence: 2, timestamp: 100_000_000, dx: 0, dy: 40, phase: .changed))
    let endedStartedMomentum = synthesizer.handle(scrollEvent(sequence: 3, timestamp: 120_000_000, dx: 0, dy: 0, phase: .ended))

    #expect(!beganStartedMomentum)
    #expect(!changedStartedMomentum)
    #expect(endedStartedMomentum)

    let first = synthesizer.nextMomentumCommand(at: 136_666_667)
    let second = synthesizer.nextMomentumCommand(at: 153_333_334)

    #expect(first?.isScroll(dx: 0, dy: 7.6824346, phase: .changed, momentumPhase: .began) == true)
    #expect(second?.isScroll(dx: 0, dy: 6.1459477, phase: .changed, momentumPhase: .changed) == true)
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

    let didStartMomentum = synthesizer.handle(event)
    #expect(!didStartMomentum)
    #expect(synthesizer.nextMomentumCommand(at: 16_666_667) == nil)
}

@Test func macScrollMomentumSynthesizerDoesNotBuildMomentumWhenDisabled() {
    var synthesizer = MacScrollMomentumSynthesizer(
        settings: ScrollMomentumSettings(isEnabled: false, amount: 6, decayRate: 0.95, tailWindowMilliseconds: 120),
        frameIntervalNanos: 16_666_667
    )

    let beganStartedMomentum = synthesizer.handle(scrollEvent(sequence: 1, timestamp: 0, dx: 0, dy: 24, phase: .began))
    let changedStartedMomentum = synthesizer.handle(scrollEvent(sequence: 2, timestamp: 16_666_667, dx: 0, dy: 24, phase: .changed))
    let endedStartedMomentum = synthesizer.handle(scrollEvent(sequence: 3, timestamp: 33_333_334, dx: 0, dy: 0, phase: .ended))

    #expect(!beganStartedMomentum)
    #expect(!changedStartedMomentum)
    #expect(!endedStartedMomentum)
    #expect(synthesizer.nextMomentumCommand(at: 50_000_001) == nil)
}

@Test func macScrollMomentumSynthesizerSupportsLongerNativeLikeMomentumTuning() {
    var synthesizer = MacScrollMomentumSynthesizer(
        settings: ScrollMomentumSettings(amount: 6, decayRate: 0.99, tailWindowMilliseconds: 300),
        frameIntervalNanos: 16_666_667
    )

    let beganStartedMomentum = synthesizer.handle(scrollEvent(sequence: 1, timestamp: 0, dx: 0, dy: 18, phase: .began))
    let firstChangedStartedMomentum = synthesizer.handle(scrollEvent(sequence: 2, timestamp: 16_666_667, dx: 0, dy: 20, phase: .changed))
    let secondChangedStartedMomentum = synthesizer.handle(scrollEvent(sequence: 3, timestamp: 33_333_334, dx: 0, dy: 22, phase: .changed))
    let thirdChangedStartedMomentum = synthesizer.handle(scrollEvent(sequence: 4, timestamp: 50_000_001, dx: 0, dy: 24, phase: .changed))
    let endedStartedMomentum = synthesizer.handle(scrollEvent(sequence: 5, timestamp: 66_666_668, dx: 0, dy: 0, phase: .ended))

    #expect(!beganStartedMomentum)
    #expect(!firstChangedStartedMomentum)
    #expect(!secondChangedStartedMomentum)
    #expect(!thirdChangedStartedMomentum)
    #expect(endedStartedMomentum)

    let commands = drainMomentum(from: &synthesizer, start: 83_333_335, frameInterval: 16_666_667)

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

    let sixtyHertzCommands = commands(from: inputEvents, using: &sixtyHertzSynthesizer, frameInterval: 16_666_667)
    let oneTwentyHertzCommands = commands(from: inputEvents, using: &oneTwentyHertzSynthesizer, frameInterval: 8_333_333)

    #expect(oneTwentyHertzCommands.count > sixtyHertzCommands.count)
    #expect(abs(oneTwentyHertzCommands.totalScrollDistance - sixtyHertzCommands.totalScrollDistance) < 5)
}

@Test func macScrollMomentumSynthesizerUsesActualTailSampleSpanForVelocity() {
    var regularSynthesizer = MacScrollMomentumSynthesizer(
        settings: ScrollMomentumSettings(amount: 1, decayRate: 0.95, tailWindowMilliseconds: 140),
        frameIntervalNanos: 16_666_667
    )
    var irregularSynthesizer = MacScrollMomentumSynthesizer(
        settings: ScrollMomentumSettings(amount: 1, decayRate: 0.95, tailWindowMilliseconds: 140),
        frameIntervalNanos: 16_666_667
    )

    let regularEvents = [
        scrollEvent(sequence: 1, timestamp: 0, dx: 0, dy: 20, phase: .began),
        scrollEvent(sequence: 2, timestamp: 16_666_667, dx: 0, dy: 20, phase: .changed),
        scrollEvent(sequence: 3, timestamp: 33_333_334, dx: 0, dy: 20, phase: .changed),
        scrollEvent(sequence: 4, timestamp: 50_000_001, dx: 0, dy: 0, phase: .ended),
    ]
    let irregularEvents = [
        scrollEvent(sequence: 1, timestamp: 0, dx: 0, dy: 20, phase: .began),
        scrollEvent(sequence: 2, timestamp: 16_666_667, dx: 0, dy: 20, phase: .changed),
        scrollEvent(sequence: 3, timestamp: 83_333_335, dx: 0, dy: 20, phase: .changed),
        scrollEvent(sequence: 4, timestamp: 100_000_002, dx: 0, dy: 0, phase: .ended),
    ]

    let regularCommands = commands(from: regularEvents, using: &regularSynthesizer, frameInterval: 16_666_667)
    let irregularCommands = commands(from: irregularEvents, using: &irregularSynthesizer, frameInterval: 16_666_667)

    #expect(irregularCommands.firstScrollDelta < regularCommands.firstScrollDelta)
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
    using synthesizer: inout MacScrollMomentumSynthesizer,
    frameInterval: UInt64
) -> [MacInputCommand] {
    for event in events {
        _ = synthesizer.handle(event)
    }

    guard let endTimestamp = events.last?.timestampNanos else {
        return []
    }

    return drainMomentum(from: &synthesizer, start: endTimestamp + frameInterval, frameInterval: frameInterval)
}

private func drainMomentum(
    from synthesizer: inout MacScrollMomentumSynthesizer,
    start: UInt64,
    frameInterval: UInt64
) -> [MacInputCommand] {
    var timestamp = start
    var commands: [MacInputCommand] = []
    for _ in 0..<400 {
        guard let command = synthesizer.nextMomentumCommand(at: timestamp) else {
            timestamp += frameInterval
            continue
        }
        commands.append(command)
        if command == .scroll(dx: 0, dy: 0, phase: .ended, momentumPhase: .ended) {
            break
        }
        timestamp += frameInterval
    }
    return commands
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

    var firstScrollDelta: Double {
        for command in self {
            guard case .scroll(let dx, let dy, .changed, _) = command else {
                continue
            }

            return abs(dx) + abs(dy)
        }

        return 0
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
