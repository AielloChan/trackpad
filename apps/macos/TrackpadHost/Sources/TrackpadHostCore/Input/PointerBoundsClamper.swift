import CoreGraphics

enum PointerBoundsClamper {
    static func locationAfterApplyingDelta(
        current: CGPoint,
        dx: Double,
        dy: Double,
        displayBounds: [CGRect]
    ) -> CGPoint {
        let clampedCurrent = clamped(current, to: displayBounds)
        let next = CGPoint(x: clampedCurrent.x + dx, y: clampedCurrent.y + dy)
        return clamped(next, to: displayBounds)
    }

    static func clamped(_ point: CGPoint, to displayBounds: [CGRect]) -> CGPoint {
        let nonEmptyBounds = displayBounds.filter { !$0.isEmpty && !$0.isNull }
        guard !nonEmptyBounds.isEmpty else {
            return point
        }

        if nonEmptyBounds.contains(where: { $0.containsInclusive(point) }) {
            return point
        }

        return nonEmptyBounds
            .map { $0.closestPoint(to: point) }
            .min { lhs, rhs in
                lhs.squaredDistance(to: point) < rhs.squaredDistance(to: point)
            } ?? point
    }
}

private extension CGRect {
    func containsInclusive(_ point: CGPoint) -> Bool {
        point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
    }

    func closestPoint(to point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, minX), maxX),
            y: min(max(point.y, minY), maxY)
        )
    }
}

private extension CGPoint {
    func squaredDistance(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return dx * dx + dy * dy
    }
}
