import Darwin
import Foundation
import CoreGraphics

struct MacSpacesNavigator: Sendable {
    enum Direction: Sendable {
        case previous
        case next
    }

    func move(
        _ direction: Direction,
        diagnostics: (@Sendable (String) -> Void)? = nil
    ) -> Bool {
        guard let connection = Self.defaultConnection?() else {
            diagnostics?("######### host.spaces direction=\(direction.logValue) failed=missingConnection")
            return false
        }

        guard let displays = Self.copyManagedDisplaySpaces?(connection)?.takeRetainedValue() as? [[String: Any]] else {
            diagnostics?("######### host.spaces direction=\(direction.logValue) failed=missingDisplays")
            return false
        }

        let preferredDisplayID = Self.pointerDisplayIdentifier()
        guard let target = Self.targetSpace(
            in: displays,
            direction: direction,
            preferredDisplayID: preferredDisplayID
        ) else {
            diagnostics?("######### host.spaces direction=\(direction.logValue) pointerDisplay=\(preferredDisplayID ?? "nil") failed=missingTarget displays=\(Self.displaySummary(displays))")
            return false
        }

        guard let setCurrentSpace = Self.setCurrentSpace else {
            diagnostics?("######### host.spaces direction=\(direction.logValue) pointerDisplay=\(preferredDisplayID ?? "nil") failed=missingSetCurrentSpace")
            return false
        }

        diagnostics?("######### host.spaces direction=\(direction.logValue) pointerDisplay=\(preferredDisplayID ?? "nil") targetDisplay=\(target.displayID) current=\(target.currentSpaceID) target=\(target.spaceID) displays=\(Self.displaySummary(displays))")
        setCurrentSpace(connection, target.displayID as CFString, target.spaceID)
        return true
    }

    static func targetSpace(
        in displays: [[String: Any]],
        direction: Direction,
        preferredDisplayID: String? = nil
    ) -> (displayID: String, currentSpaceID: UInt64, spaceID: UInt64)? {
        if let preferredDisplayID,
           let display = displays.first(where: { $0["Display Identifier"] as? String == preferredDisplayID }),
           let target = targetSpace(in: display, direction: direction) {
            return target
        }

        for display in displays {
            if let target = targetSpace(in: display, direction: direction) {
                return target
            }
        }

        return nil
    }

    private static func targetSpace(
        in display: [String: Any],
        direction: Direction
    ) -> (displayID: String, currentSpaceID: UInt64, spaceID: UInt64)? {
        guard let displayID = display["Display Identifier"] as? String,
              let current = display["Current Space"] as? [String: Any],
              let spaces = display["Spaces"] as? [[String: Any]],
              let currentID = integerValue(current["id64"]),
              let currentIndex = spaces.firstIndex(where: { integerValue($0["id64"]) == currentID }) else {
            return nil
        }

        let targetIndex: Int
        switch direction {
        case .previous:
            targetIndex = currentIndex - 1
        case .next:
            targetIndex = currentIndex + 1
        }

        guard spaces.indices.contains(targetIndex),
              let targetID = integerValue(spaces[targetIndex]["id64"]) else {
            return nil
        }

        return (displayID: displayID, currentSpaceID: currentID, spaceID: targetID)
    }

    private static func pointerDisplayIdentifier() -> String? {
        guard let location = CGEvent(source: nil)?.location else {
            return nil
        }

        var displayID = CGDirectDisplayID(0)
        var displayCount: UInt32 = 0
        guard CGGetDisplaysWithPoint(location, 1, &displayID, &displayCount) == .success,
              displayCount > 0 else {
            return nil
        }

        return displayIdentifier(for: displayID)
    }

    private static func displayIdentifier(for displayID: CGDirectDisplayID) -> String? {
        guard let uuid = displayUUIDFromDisplayID?(displayID)?.takeRetainedValue(),
              let string = CFUUIDCreateString(nil, uuid) else {
            return nil
        }

        return string as String
    }

    private static func displaySummary(_ displays: [[String: Any]]) -> String {
        displays.map { display in
            let displayID = display["Display Identifier"] as? String ?? "unknown"
            let current = (display["Current Space"] as? [String: Any])
                .flatMap { integerValue($0["id64"]) }
                .map(String.init) ?? "nil"
            let spaces = (display["Spaces"] as? [[String: Any]])?
                .compactMap { integerValue($0["id64"]).map(String.init) }
                .joined(separator: ",") ?? ""

            return "\(displayID):current=\(current):spaces=[\(spaces)]"
        }
        .joined(separator: "|")
    }

    private static func integerValue(_ value: Any?) -> UInt64? {
        if let value = value as? UInt64 {
            return value
        }
        if let value = value as? Int {
            return UInt64(value)
        }
        if let value = value as? NSNumber {
            return value.uint64Value
        }
        return nil
    }

    private typealias DefaultConnection = @convention(c) () -> Int32
    private typealias CopyManagedDisplaySpaces = @convention(c) (Int32) -> Unmanaged<CFArray>?
    private typealias SetCurrentSpace = @convention(c) (Int32, CFString, UInt64) -> Void
    private typealias DisplayUUIDFromDisplayID = @convention(c) (CGDirectDisplayID) -> Unmanaged<CFUUID>?

    private static let defaultConnection: DefaultConnection? = loadSymbol("_CGSDefaultConnection", as: DefaultConnection.self)
    private static let copyManagedDisplaySpaces: CopyManagedDisplaySpaces? = loadSymbol("CGSCopyManagedDisplaySpaces", as: CopyManagedDisplaySpaces.self)
    private static let setCurrentSpace: SetCurrentSpace? = loadSymbol("CGSManagedDisplaySetCurrentSpace", as: SetCurrentSpace.self)
    private static let displayUUIDFromDisplayID: DisplayUUIDFromDisplayID? = loadSymbol("CGDisplayCreateUUIDFromDisplayID", as: DisplayUUIDFromDisplayID.self)

    private static func loadSymbol<T>(_ name: String, as type: T.Type) -> T? {
        _ = dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_LAZY)
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) else {
            return nil
        }
        return unsafeBitCast(symbol, to: type)
    }
}

private extension MacSpacesNavigator.Direction {
    var logValue: String {
        switch self {
        case .previous:
            return "previous"
        case .next:
            return "next"
        }
    }
}
