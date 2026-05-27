public struct DiscoveredTrackpadHost: Identifiable, Equatable, Sendable {
    public let name: String
    public let type: String
    public let domain: String

    public init(
        name: String,
        type: String = TrackpadDiscoveryDefaults.bonjourType,
        domain: String = TrackpadDiscoveryDefaults.bonjourDomain
    ) {
        self.name = name
        self.type = type
        self.domain = domain
    }

    public var id: String {
        "\(name).\(type).\(domain)"
    }

    public var address: TrackpadHostAddress {
        .bonjour(name: name, type: type, domain: domain)
    }
}
