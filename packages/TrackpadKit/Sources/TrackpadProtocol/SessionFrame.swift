public enum SessionFrame: Codable, Equatable, Sendable {
    case clientHello(ClientHello)
    case input(InputEvent)
    case ping(SessionPing)
    case pong(SessionPong)
    case rejected(SessionRejected)
}

public struct ClientHello: Codable, Equatable, Sendable {
    public let protocolVersion: Int
    public let deviceId: String
    public let deviceName: String
    public let pairingCode: String

    public init(
        protocolVersion: Int,
        deviceId: String,
        deviceName: String,
        pairingCode: String
    ) {
        self.protocolVersion = protocolVersion
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.pairingCode = pairingCode
    }
}

public struct SessionRejected: Codable, Equatable, Sendable {
    public let reason: String

    public init(reason: String) {
        self.reason = reason
    }
}

public struct SessionPing: Codable, Equatable, Sendable {
    public let id: UInt64
    public let clientSentNanos: UInt64

    public init(id: UInt64, clientSentNanos: UInt64) {
        self.id = id
        self.clientSentNanos = clientSentNanos
    }
}

public struct SessionPong: Codable, Equatable, Sendable {
    public let id: UInt64
    public let clientSentNanos: UInt64
    public let hostReceivedNanos: UInt64

    public init(id: UInt64, clientSentNanos: UInt64, hostReceivedNanos: UInt64) {
        self.id = id
        self.clientSentNanos = clientSentNanos
        self.hostReceivedNanos = hostReceivedNanos
    }
}
