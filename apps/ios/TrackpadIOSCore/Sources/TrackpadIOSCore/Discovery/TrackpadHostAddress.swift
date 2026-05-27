import Network

public enum TrackpadDiscoveryDefaults {
    public static let bonjourType = "_trackpad-host._tcp"
    public static let bonjourDomain = "local."
}

public enum TrackpadHostAddress: Equatable, Sendable {
    case manual(host: String, port: UInt16)
    case bonjour(name: String, type: String, domain: String)

    public var connectionEndpoint: NWEndpoint {
        switch self {
        case .manual(let host, let port):
            .hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!)
        case .bonjour(let name, let type, let domain):
            .service(name: name, type: type, domain: domain, interface: nil)
        }
    }

    public var displayName: String {
        switch self {
        case .manual(let host, let port):
            "\(host):\(port)"
        case .bonjour(let name, _, _):
            name
        }
    }
}
