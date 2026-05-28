import CoreGraphics
import Testing
@testable import TrackpadHostCore

@Test func pointerDeltaStartsFromClampedCurrentLocationAtDisplayEdge() {
    let display = CGRect(x: 0, y: 0, width: 100, height: 80)

    let next = PointerBoundsClamper.locationAfterApplyingDelta(
        current: CGPoint(x: 135, y: 40),
        dx: -5,
        dy: 0,
        displayBounds: [display]
    )

    #expect(next == CGPoint(x: 95, y: 40))
}

@Test func pointerDeltaCannotAccumulateOutsideDisplayBounds() {
    let display = CGRect(x: 0, y: 0, width: 100, height: 80)

    let next = PointerBoundsClamper.locationAfterApplyingDelta(
        current: CGPoint(x: 95, y: 40),
        dx: 30,
        dy: 0,
        displayBounds: [display]
    )

    #expect(next == CGPoint(x: 100, y: 40))
}

@Test func pointerClampChoosesNearestDisplayInMultiDisplayLayout() {
    let left = CGRect(x: 0, y: 0, width: 100, height: 80)
    let right = CGRect(x: 120, y: 0, width: 100, height: 80)

    let next = PointerBoundsClamper.locationAfterApplyingDelta(
        current: CGPoint(x: 130, y: 90),
        dx: 20,
        dy: -20,
        displayBounds: [left, right]
    )

    #expect(next == CGPoint(x: 150, y: 60))
}

@Test func pointerClampReturnsOriginalPointWhenDisplayBoundsAreUnavailable() {
    let point = CGPoint(x: 500, y: -200)

    #expect(PointerBoundsClamper.clamped(point, to: []) == point)
}
