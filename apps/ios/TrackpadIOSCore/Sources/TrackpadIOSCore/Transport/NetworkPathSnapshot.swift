import Foundation
#if canImport(Network)
import Network
#endif

public enum NetworkPathStatus: String, Equatable, Sendable {
    case satisfied
    case unsatisfied
    case requiresConnection
    case unknown
}

public enum NetworkInterfaceKind: String, CaseIterable, Equatable, Sendable {
    case wiredEthernet
    case wifi
    case cellular
    case loopback
    case other

    var priority: Int {
        switch self {
        case .wiredEthernet:
            return 0
        case .wifi:
            return 1
        case .cellular:
            return 2
        case .loopback:
            return 3
        case .other:
            return 4
        }
    }

    public var label: String {
        switch self {
        case .wiredEthernet:
            return "Wired"
        case .wifi:
            return "Wi-Fi"
        case .cellular:
            return "Cellular"
        case .loopback:
            return "Loopback"
        case .other:
            return "Other"
        }
    }
}

public struct NetworkPathSnapshot: Equatable, Sendable {
    public let status: NetworkPathStatus
    public let interfaceKinds: [NetworkInterfaceKind]
    public let isExpensive: Bool
    public let isConstrained: Bool

    public init(
        status: NetworkPathStatus,
        interfaceKinds: [NetworkInterfaceKind],
        isExpensive: Bool = false,
        isConstrained: Bool = false
    ) {
        self.status = status
        self.interfaceKinds = Self.sortedUnique(interfaceKinds)
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
    }

    public var isCableCandidate: Bool {
        interfaceKinds.contains(.wiredEthernet)
    }

    public var preferredInterfaceKind: NetworkInterfaceKind? {
        interfaceKinds.first
    }

    public var shortLabel: String {
        guard status == .satisfied else {
            return "Path --"
        }

        guard let preferredInterfaceKind else {
            return "Path Unknown"
        }

        if isCableCandidate {
            return "Path \(preferredInterfaceKind.label)"
        }

        if isConstrained {
            return "Path \(preferredInterfaceKind.label) Low Data"
        }

        if isExpensive {
            return "Path \(preferredInterfaceKind.label) Expensive"
        }

        return "Path \(preferredInterfaceKind.label)"
    }

    private static func sortedUnique(_ kinds: [NetworkInterfaceKind]) -> [NetworkInterfaceKind] {
        var seen: Set<NetworkInterfaceKind> = []
        return kinds
            .filter { seen.insert($0).inserted }
            .sorted { $0.priority < $1.priority }
    }
}

#if canImport(Network)
public extension NetworkPathSnapshot {
    init(path: NWPath) {
        self.init(
            status: NetworkPathStatus(pathStatus: path.status),
            interfaceKinds: NetworkInterfaceKind.kinds(in: path),
            isExpensive: path.isExpensive,
            isConstrained: path.isConstrained
        )
    }
}

private extension NetworkPathStatus {
    init(pathStatus: NWPath.Status) {
        switch pathStatus {
        case .satisfied:
            self = .satisfied
        case .unsatisfied:
            self = .unsatisfied
        case .requiresConnection:
            self = .requiresConnection
        @unknown default:
            self = .unknown
        }
    }
}

private extension NetworkInterfaceKind {
    static func kinds(in path: NWPath) -> [NetworkInterfaceKind] {
        var kinds: [NetworkInterfaceKind] = []
        if path.usesInterfaceType(.wiredEthernet) {
            kinds.append(.wiredEthernet)
        }
        if path.usesInterfaceType(.wifi) {
            kinds.append(.wifi)
        }
        if path.usesInterfaceType(.cellular) {
            kinds.append(.cellular)
        }
        if path.usesInterfaceType(.loopback) {
            kinds.append(.loopback)
        }
        if path.usesInterfaceType(.other) {
            kinds.append(.other)
        }
        return kinds
    }
}
#endif
