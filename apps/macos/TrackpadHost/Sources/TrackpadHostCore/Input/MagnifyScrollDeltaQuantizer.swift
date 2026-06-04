import Foundation
import TrackpadKit

struct MagnifyScrollDeltaQuantizer {
    private let scale: Double
    private let maximumDeltaPerReport: Int
    private var residual: Double = 0

    init(scale: Double = 360, maximumDeltaPerReport: Int = 120) {
        self.scale = scale
        self.maximumDeltaPerReport = maximumDeltaPerReport
    }

    mutating func integerDelta(magnification: Double, phase: ScrollPhase) -> Int {
        if phase == .ended {
            residual = 0
            return 0
        }

        residual += magnification * scale
        let delta = Int(residual)
        guard delta != 0 else {
            return 0
        }

        let limitedDelta = min(max(delta, -maximumDeltaPerReport), maximumDeltaPerReport)
        residual -= Double(limitedDelta)
        return limitedDelta
    }
}

final class LockedMagnifyScrollDeltaQuantizer: @unchecked Sendable {
    private let lock = NSLock()
    private var quantizer = MagnifyScrollDeltaQuantizer()

    func integerDelta(magnification: Double, phase: ScrollPhase) -> Int {
        lock.lock()
        defer {
            lock.unlock()
        }

        return quantizer.integerDelta(magnification: magnification, phase: phase)
    }
}
