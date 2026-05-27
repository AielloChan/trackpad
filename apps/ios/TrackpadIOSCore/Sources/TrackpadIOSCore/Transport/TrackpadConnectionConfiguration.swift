public struct TrackpadConnectionConfiguration: Equatable, Sendable {
    public let address: TrackpadHostAddress
    public let host: String
    public let port: UInt16
    public let pairingCode: String
    public let deviceId: String
    public let deviceName: String

    public init(
        host: String,
        port: UInt16,
        pairingCode: String,
        deviceId: String,
        deviceName: String
    ) {
        self.address = .manual(host: host, port: port)
        self.host = host
        self.port = port
        self.pairingCode = pairingCode
        self.deviceId = deviceId
        self.deviceName = deviceName
    }

    public init(
        address: TrackpadHostAddress,
        pairingCode: String,
        deviceId: String,
        deviceName: String
    ) {
        self.address = address
        switch address {
        case .manual(let host, let port):
            self.host = host
            self.port = port
        case .bonjour(let name, _, _):
            self.host = name
            self.port = 0
        }
        self.pairingCode = pairingCode
        self.deviceId = deviceId
        self.deviceName = deviceName
    }
}
