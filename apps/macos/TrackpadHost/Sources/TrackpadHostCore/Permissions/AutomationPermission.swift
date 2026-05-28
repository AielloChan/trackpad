import Foundation

public enum AutomationPermission {
    public static func requestSystemEventsAccess(logger: any HostLogging = DisabledHostLogger()) -> Bool {
        runSystemEventsProbe(logger: logger, shouldLogSuccess: true)
    }

    public static func checkSystemEventsAccess(logger: any HostLogging = DisabledHostLogger()) -> Bool {
        runSystemEventsProbe(logger: logger, shouldLogSuccess: false)
    }

    private static func runSystemEventsProbe(logger: any HostLogging, shouldLogSuccess: Bool) -> Bool {
        let source = """
        tell application "System Events"
            count processes
        end tell
        """
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            logger.error(category: "permission", "automation scriptCreateFailed")
            return false
        }

        script.executeAndReturnError(&error)
        if let error {
            logger.error(category: "permission", "automation error=\(error)")
            return false
        }

        if shouldLogSuccess {
            logger.info(category: "permission", "automation granted")
        }
        return true
    }
}
