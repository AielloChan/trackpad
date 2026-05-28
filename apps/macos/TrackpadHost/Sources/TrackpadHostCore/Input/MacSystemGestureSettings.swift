import Foundation
import TrackpadKit

public struct MacSystemGestureSettings: Equatable, Sendable {
    public let threeFingerVerticalSwipeEnabled: Bool
    public let threeFingerHorizontalSwipeEnabled: Bool
    public let threeFingerDragEnabled: Bool

    public init(
        threeFingerVerticalSwipeEnabled: Bool,
        threeFingerHorizontalSwipeEnabled: Bool,
        threeFingerDragEnabled: Bool
    ) {
        self.threeFingerVerticalSwipeEnabled = threeFingerVerticalSwipeEnabled
        self.threeFingerHorizontalSwipeEnabled = threeFingerHorizontalSwipeEnabled
        self.threeFingerDragEnabled = threeFingerDragEnabled
    }

    public static let allThreeFingerSwipesEnabled = MacSystemGestureSettings(
        threeFingerVerticalSwipeEnabled: true,
        threeFingerHorizontalSwipeEnabled: true,
        threeFingerDragEnabled: false
    )

    public static func current() -> MacSystemGestureSettings {
        let primary = UserDefaults.standard.persistentDomain(forName: "com.apple.AppleMultitouchTrackpad") ?? [:]
        let bluetooth = UserDefaults.standard.persistentDomain(forName: "com.apple.driver.AppleBluetoothMultitouch.trackpad") ?? [:]
        return MacSystemGestureSettings(
            threeFingerVerticalSwipeEnabled: gestureValue("TrackpadThreeFingerVertSwipeGesture", primary: primary, fallback: bluetooth) == 2,
            threeFingerHorizontalSwipeEnabled: gestureValue("TrackpadThreeFingerHorizSwipeGesture", primary: primary, fallback: bluetooth) == 2,
            threeFingerDragEnabled: gestureValue("TrackpadThreeFingerDrag", primary: primary, fallback: bluetooth) == 1
        )
    }

    public func allowsThreeFingerSystemAction(_ action: SystemAction) -> Bool {
        guard !threeFingerDragEnabled else {
            return false
        }

        switch action {
        case .missionControl, .appExpose:
            return threeFingerVerticalSwipeEnabled
        case .previousSpace, .nextSpace:
            return threeFingerHorizontalSwipeEnabled
        }
    }

    private static func gestureValue(
        _ key: String,
        primary: [String: Any],
        fallback: [String: Any]
    ) -> Int {
        if let value = primary[key] as? Int {
            return value
        }
        if let value = fallback[key] as? Int {
            return value
        }
        return 0
    }
}
