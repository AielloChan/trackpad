import Darwin
import Foundation

public struct HostNetworkAddress: Equatable, Sendable {
    public let interfaceName: String
    public let address: String
    public let isLoopback: Bool

    public init(interfaceName: String, address: String, isLoopback: Bool) {
        self.interfaceName = interfaceName
        self.address = address
        self.isLoopback = isLoopback
    }
}

public enum HostNetworkAddressSelector {
    public static func preferredIPv4Address(from addresses: [HostNetworkAddress]) -> String? {
        let candidates = addresses.filter { !$0.isLoopback }

        if let primaryWiFi = candidates.first(where: { $0.interfaceName == "en0" }) {
            return primaryWiFi.address
        }

        return candidates.first?.address
    }
}

public enum HostNetworkAddressProvider {
    public static func primaryIPv4Address() -> String? {
        HostNetworkAddressSelector.preferredIPv4Address(from: ipv4Addresses())
    }

    public static func ipv4Addresses() -> [HostNetworkAddress] {
        var interfaceAddresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaceAddresses) == 0, let firstAddress = interfaceAddresses else {
            return []
        }

        defer {
            freeifaddrs(interfaceAddresses)
        }

        var addresses: [HostNetworkAddress] = []
        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddress
        while let interface = cursor?.pointee {
            defer {
                cursor = interface.ifa_next
            }

            guard let socketAddress = interface.ifa_addr,
                  socketAddress.pointee.sa_family == UInt8(AF_INET) else {
                continue
            }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                socketAddress,
                socklen_t(socketAddress.pointee.sa_len),
                &host,
                socklen_t(host.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            guard result == 0 else {
                continue
            }

            let flags = Int32(interface.ifa_flags)
            addresses.append(
                HostNetworkAddress(
                    interfaceName: String(cString: interface.ifa_name),
                    address: Self.string(fromNullTerminatedCString: host),
                    isLoopback: (flags & IFF_LOOPBACK) != 0
                )
            )
        }

        return addresses
    }

    private static func string(fromNullTerminatedCString value: [CChar]) -> String {
        let bytes = value.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }
}
