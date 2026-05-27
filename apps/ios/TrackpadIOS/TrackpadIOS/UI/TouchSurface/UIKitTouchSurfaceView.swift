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
        onTouchMoved(activeContacts(from: event))
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

            let point = touch.location(in: self)
            return TouchContact(
                id: ObjectIdentifier(touch).hashValue,
                point: TouchPoint(x: point.x, y: point.y)
            )
        }
    }
}
