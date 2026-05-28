import Foundation
import TrackpadKit

struct ScrollWheelIntegerDeltas: Equatable, Sendable {
    let dx: Int32
    let dy: Int32
}

struct ScrollWheelIntegerDeltaQuantizer: Sendable {
    private var residualDx = 0.0
    private var residualDy = 0.0

    mutating func integerDeltas(dx: Double, dy: Double, phase: ScrollPhase) -> ScrollWheelIntegerDeltas {
        if phase == .began {
            reset()
        }

        let deltas = ScrollWheelIntegerDeltas(
            dx: integerDelta(for: dx, residual: &residualDx),
            dy: integerDelta(for: dy, residual: &residualDy)
        )

        if phase == .ended {
            reset()
        }

        return deltas
    }

    mutating func reset() {
        residualDx = 0
        residualDy = 0
    }

    private func integerDelta(for delta: Double, residual: inout Double) -> Int32 {
        guard delta.isFinite, delta != 0 else {
            return 0
        }

        if residual != 0, residual.sign != delta.sign {
            residual = 0
        }

        residual += delta
        let whole = residual.rounded(.towardZero)
        guard whole != 0 else {
            return 0
        }

        residual -= whole
        return Int32(whole.clamped(to: Double(Int32.min)...Double(Int32.max)))
    }
}

final class LockedScrollWheelIntegerDeltaQuantizer: @unchecked Sendable {
    private let lock = NSLock()
    private var quantizer = ScrollWheelIntegerDeltaQuantizer()

    func integerDeltas(dx: Double, dy: Double, phase: ScrollPhase) -> ScrollWheelIntegerDeltas {
        lock.lock()
        defer {
            lock.unlock()
        }

        return quantizer.integerDeltas(dx: dx, dy: dy, phase: phase)
    }

    func reset() {
        lock.lock()
        defer {
            lock.unlock()
        }

        quantizer.reset()
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
