import Testing
import TrackpadKit
@testable import TrackpadIOSCore

@Test func scrollMomentumPlannerCreatesDecayingStepsAndFinalEnd() {
    let steps = ScrollMomentumPlanner().steps(initialDx: 0, initialDy: 12)

    #expect(steps.count > 25)
    #expect(steps.first?.delayNanos == 16_000_000)
    #expect(abs((steps.first?.dy ?? 0) - 11.04) < 0.0001)
    #expect(abs((steps.dropLast().last?.dy ?? 0)) < abs(steps.first?.dy ?? 0))
    #expect(steps.last?.phase == .ended)
}

@Test func scrollMomentumPlannerIgnoresTinyInitialDeltas() {
    let steps = ScrollMomentumPlanner().steps(initialDx: 0, initialDy: 0.4)

    #expect(steps.isEmpty)
}

@Test func scrollMomentumPlannerCreatesStepsFromInitialVelocity() {
    let steps = ScrollMomentumPlanner().steps(initialVelocityDxPerSecond: 0, initialVelocityDyPerSecond: 1_500)

    #expect(steps.count > 45)
    #expect(steps.first?.delayNanos == 16_000_000)
    #expect(steps.first?.dy == 24)
    #expect(abs((steps.dropLast().last?.dy ?? 0)) < abs(steps.first?.dy ?? 0))
    #expect(steps.last?.phase == .ended)
}

@Test func scrollMomentumPlannerIgnoresTinyInitialVelocity() {
    let steps = ScrollMomentumPlanner().steps(initialVelocityDxPerSecond: 0, initialVelocityDyPerSecond: 20)

    #expect(steps.isEmpty)
}

@Test func scrollMomentumPlannerScalesInitialVelocityByAmount() {
    let steps = ScrollMomentumPlanner().steps(
        initialVelocityDxPerSecond: 0,
        initialVelocityDyPerSecond: 1_500,
        amount: 2
    )

    #expect(steps.first?.dy == 48)
}

@Test func scrollMomentumSeedKeepsVerticalVelocityAfterHorizontalJitter() {
    var tracker = ScrollMomentumSeedTracker()

    tracker.record(
        scroll: ScrollEvent(dx: 0, dy: 12, phase: .changed),
        velocity: ScrollVelocity(dxPerSecond: 0, dyPerSecond: 750)
    )
    tracker.record(
        scroll: ScrollEvent(dx: 5, dy: 0.2, phase: .changed),
        velocity: ScrollVelocity(dxPerSecond: 312.5, dyPerSecond: 12.5)
    )

    #expect(tracker.seedVelocity() == ScrollVelocity(dxPerSecond: 0, dyPerSecond: 750))
}

@Test func scrollMomentumSeedKeepsHorizontalVelocityForHorizontalScroll() {
    var tracker = ScrollMomentumSeedTracker()

    tracker.record(
        scroll: ScrollEvent(dx: 14, dy: 0, phase: .changed),
        velocity: ScrollVelocity(dxPerSecond: 875, dyPerSecond: 0)
    )
    tracker.record(
        scroll: ScrollEvent(dx: 3, dy: 0.2, phase: .changed),
        velocity: ScrollVelocity(dxPerSecond: 187.5, dyPerSecond: 12.5)
    )

    #expect(tracker.seedVelocity() == ScrollVelocity(dxPerSecond: 187.5, dyPerSecond: 0))
}
