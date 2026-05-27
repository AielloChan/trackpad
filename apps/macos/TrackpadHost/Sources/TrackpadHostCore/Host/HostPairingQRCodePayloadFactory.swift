import TrackpadKit

public struct HostPairingQRCodePayload: Equatable, Sendable {
    public let message: String
    public let host: String
    public let port: UInt16

    public init(message: String, host: String, port: UInt16) {
        self.message = message
        self.host = host
        self.port = port
    }
}

public enum HostPairingQRCodePayloadFactory {
    public static func make(
        pairingCode: PairingCode,
        host: String? = HostNetworkAddressProvider.primaryIPv4Address(),
        port: UInt16 = HostDefaults.tcpPort,
        serviceName: String = HostDefaults.bonjourName
    ) -> HostPairingQRCodePayload? {
        guard let host, !host.isEmpty else {
            return nil
        }

        let payload = PairingQRCodePayload(
            host: host,
            port: port,
            pairingCode: pairingCode.value,
            serviceName: serviceName
        )

        return HostPairingQRCodePayload(
            message: payload.urlString,
            host: host,
            port: port
        )
    }
}
