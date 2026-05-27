import Foundation

public struct HostRuntimeStatus: Equatable, Sendable {
    public enum State: String, Equatable, Sendable {
        case stopped
        case starting
        case running
        case failed
    }

    public let state: State
    public let port: UInt16?
    public let connectionCount: Int
    public let authorizedConnectionCount: Int
    public let handledEventCount: Int
    public let lastError: String?

    public init(
        state: State,
        port: UInt16? = nil,
        connectionCount: Int = 0,
        authorizedConnectionCount: Int = 0,
        handledEventCount: Int = 0,
        lastError: String? = nil
    ) {
        self.state = state
        self.port = port
        self.connectionCount = connectionCount
        self.authorizedConnectionCount = authorizedConnectionCount
        self.handledEventCount = handledEventCount
        self.lastError = lastError
    }

    public static let stopped = HostRuntimeStatus(state: .stopped)
}

public enum HostDefaults {
    public static let tcpPort: UInt16 = 44787
    public static let bonjourType = "_trackpad-host._tcp"
    public static let bonjourName = "Trackpad Host"
}
