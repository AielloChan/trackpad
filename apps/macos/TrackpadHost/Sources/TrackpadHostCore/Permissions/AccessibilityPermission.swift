import ApplicationServices

public enum AccessibilityPermission {
    public static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    public static func requestIfNeeded() {
        guard !isTrusted else {
            return
        }

        let options = [
            "AXTrustedCheckOptionPrompt": true,
        ] as CFDictionary

        _ = AXIsProcessTrustedWithOptions(options)
    }
}
