import Foundation
#if SWIFT_PACKAGE
import TrackpadKit
#endif

public struct ScrollMomentumSeedTracker: Sendable {
    private var totalAbsoluteDx = 0.0
    private var totalAbsoluteDy = 0.0
    private var latestDxVelocity: Double?
    private var latestDyVelocity: Double?
    private let axisDeltaThreshold: Double
    private let dominantAxisRatio: Double

    public init(axisDeltaThreshold: Double = 0.6, dominantAxisRatio: Double = 1.5) {
        self.axisDeltaThreshold = axisDeltaThreshold
        self.dominantAxisRatio = dominantAxisRatio
    }

    public mutating func record(scroll: ScrollEvent, velocity: ScrollVelocity?) {
        guard scroll.phase == .began || scroll.phase == .changed else {
            return
        }

        let absoluteDx = abs(scroll.dx)
        let absoluteDy = abs(scroll.dy)
        totalAbsoluteDx += absoluteDx
        totalAbsoluteDy += absoluteDy

        if absoluteDx >= axisDeltaThreshold {
            latestDxVelocity = velocity?.dxPerSecond
        }
        if absoluteDy >= axisDeltaThreshold {
            latestDyVelocity = velocity?.dyPerSecond
        }
    }

    public func seedVelocity() -> ScrollVelocity? {
        let dx = latestDxVelocity ?? 0
        let dy = latestDyVelocity ?? 0
        let usesVerticalAxis = totalAbsoluteDy >= totalAbsoluteDx * dominantAxisRatio
        let usesHorizontalAxis = totalAbsoluteDx >= totalAbsoluteDy * dominantAxisRatio
        let seed: ScrollVelocity

        if usesVerticalAxis {
            seed = ScrollVelocity(dxPerSecond: 0, dyPerSecond: dy)
        } else if usesHorizontalAxis {
            seed = ScrollVelocity(dxPerSecond: dx, dyPerSecond: 0)
        } else {
            seed = ScrollVelocity(dxPerSecond: dx, dyPerSecond: dy)
        }

        guard abs(seed.dxPerSecond) > 0 || abs(seed.dyPerSecond) > 0 else {
            return nil
        }

        return seed
    }

    public mutating func reset() {
        totalAbsoluteDx = 0
        totalAbsoluteDy = 0
        latestDxVelocity = nil
        latestDyVelocity = nil
    }
}
