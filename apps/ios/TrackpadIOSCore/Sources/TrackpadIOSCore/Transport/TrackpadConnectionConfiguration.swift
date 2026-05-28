public struct TrackpadConnectionConfiguration: Equatable, Sendable {
    public let address: TrackpadHostAddress
    public let host: String
    public let port: UInt16
    public let pairingCode: String
    public let deviceId: String
    public let deviceName: String
    public let trustedClientKey: String?
    public let trustedHostIdentity: String
    public let trustedHostAliases: [String]

    public init(
        host: String,
        port: UInt16,
        pairingCode: String,
        deviceId: String,
        deviceName: String,
        trustedClientKey: String? = nil,
        trustedHostAliases: [String] = []
    ) {
        self.address = .manual(host: host, port: port)
        self.host = host
        self.port = port
        self.pairingCode = pairingCode
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.trustedClientKey = trustedClientKey
        self.trustedHostIdentity = "\(host):\(port)"
        self.trustedHostAliases = trustedHostAliases
    }

    public init(
        address: TrackpadHostAddress,
        pairingCode: String,
        deviceId: String,
        deviceName: String,
        trustedClientKey: String? = nil,
        trustedHostAliases: [String] = []
    ) {
        self.address = address
        switch address {
        case .manual(let host, let port):
            self.host = host
            self.port = port
            self.trustedHostIdentity = "\(host):\(port)"
        case .bonjour(let name, _, _):
            self.host = name
            self.port = 0
            self.trustedHostIdentity = "bonjour:\(name)"
        }
        self.pairingCode = pairingCode
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.trustedClientKey = trustedClientKey
        self.trustedHostAliases = trustedHostAliases
    }

    public var trustedHostIdentities: [String] {
        var identities = [trustedHostIdentity]
        for alias in trustedHostAliases where !identities.contains(alias) {
            identities.append(alias)
        }
        return identities
    }
}
