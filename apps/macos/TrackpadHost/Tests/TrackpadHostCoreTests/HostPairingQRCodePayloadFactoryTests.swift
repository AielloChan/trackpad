import Testing
@testable import TrackpadHostCore
import TrackpadKit

@Test func hostNetworkAddressSelectorPrefersPrimaryWiFiAddress() {
    let address = HostNetworkAddressSelector.preferredIPv4Address(from: [
        HostNetworkAddress(interfaceName: "lo0", address: "127.0.0.1", isLoopback: true),
        HostNetworkAddress(interfaceName: "en5", address: "192.168.50.10", isLoopback: false),
        HostNetworkAddress(interfaceName: "en0", address: "192.168.1.20", isLoopback: false),
    ])

    #expect(address == "192.168.1.20")
}

@Test func hostNetworkAddressSelectorFallsBackToFirstNonLoopbackAddress() {
    let address = HostNetworkAddressSelector.preferredIPv4Address(from: [
        HostNetworkAddress(interfaceName: "lo0", address: "127.0.0.1", isLoopback: true),
        HostNetworkAddress(interfaceName: "en5", address: "192.168.50.10", isLoopback: false),
    ])

    #expect(address == "192.168.50.10")
}

@Test func hostPairingQRCodePayloadFactoryBuildsDecodableMessage() throws {
    let code = PairingCode("123456")
    let payload = try #require(HostPairingQRCodePayloadFactory.make(
        pairingCode: code,
        host: "192.168.1.20",
        port: 44787,
        serviceName: "Trackpad Host"
    ))

    let decoded = try PairingQRCodePayload(urlString: payload.message)

    #expect(payload.host == "192.168.1.20")
    #expect(payload.port == 44787)
    #expect(decoded.host == "192.168.1.20")
    #expect(decoded.port == 44787)
    #expect(decoded.pairingCode == "123456")
}
