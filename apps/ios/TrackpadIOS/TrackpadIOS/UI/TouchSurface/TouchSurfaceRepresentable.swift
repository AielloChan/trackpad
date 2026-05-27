import SwiftUI

struct TouchSurfaceRepresentable: UIViewRepresentable {
    let onTouchBegan: ([TouchContact]) -> Void
    let onTouchMoved: ([TouchContact]) -> Void
    let onTouchEnded: ([TouchContact]) -> Void

    func makeUIView(context: Context) -> UIKitTouchSurfaceView {
        UIKitTouchSurfaceView()
    }

    func updateUIView(_ uiView: UIKitTouchSurfaceView, context: Context) {
        uiView.onTouchBegan = onTouchBegan
        uiView.onTouchMoved = onTouchMoved
        uiView.onTouchEnded = onTouchEnded
    }
}
