import UIKit

final class UIKitTouchSurfaceView: UIView {
    var onTouchBegan: ([TouchContact]) -> Void = { _ in }
    var onTouchMoved: ([TouchContact]) -> Void = { _ in }
    var onTouchEnded: ([TouchContact]) -> Void = { _ in }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isMultipleTouchEnabled = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        onTouchBegan(activeContacts(from: event))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if forwardSingleFingerCoalescedMoves(touches, event: event) {
            return
        }

        let contacts = activeContacts(from: event)
        onTouchMoved(contacts)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        onTouchEnded(activeContacts(from: event))
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        onTouchEnded(activeContacts(from: event))
    }

    private func activeContacts(from event: UIEvent?) -> [TouchContact] {
        let touches = event?.allTouches ?? []
        return touches.compactMap { touch in
            guard touch.phase != .ended, touch.phase != .cancelled else {
                return nil
            }

            return contact(from: touch, id: ObjectIdentifier(touch).hashValue)
        }
    }

    private func forwardSingleFingerCoalescedMoves(_ touches: Set<UITouch>, event: UIEvent?) -> Bool {
        guard let event,
              touches.count == 1,
              let touch = touches.first,
              activeTouchCount(from: event) == 1 else {
            return false
        }

        guard let samples = event.coalescedTouches(for: touch),
              samples.count > 1 else {
            return false
        }

        let id = ObjectIdentifier(touch).hashValue
        for sample in samples {
            onTouchMoved([contact(from: sample, id: id)])
        }
        return true
    }

    private func activeTouchCount(from event: UIEvent) -> Int {
        event.allTouches?.filter { touch in
            touch.phase != .ended && touch.phase != .cancelled
        }.count ?? 0
    }

    private func contact(from touch: UITouch, id: Int) -> TouchContact {
        let point = touch.preciseLocation(in: self)
        return TouchContact(
            id: id,
            point: TouchPoint(x: point.x, y: point.y),
            surfaceWidth: bounds.width
        )
    }

}
