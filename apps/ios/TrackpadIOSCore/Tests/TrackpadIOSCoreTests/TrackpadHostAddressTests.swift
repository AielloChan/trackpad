import Network
import Testing
@testable import TrackpadIOSCore

@Test func manualHostAddressBuildsHostPortEndpoint() {
    let address = TrackpadHostAddress.manual(host: "192.168.1.20", port: 44787)

    #expect(address.displayName == "192.168.1.20:44787")
    #expect(address.connectionEndpoint == .hostPort(host: "192.168.1.20", port: 44787))
}

@Test func discoveredHostBuildsBonjourAddress() {
    let host = DiscoveredTrackpadHost(name: "Trackpad Host")

    #expect(host.id == "Trackpad Host._trackpad-host._tcp.local.")
    #expect(host.address == .bonjour(name: "Trackpad Host", type: "_trackpad-host._tcp", domain: "local."))
    #expect(host.address.connectionEndpoint == .service(name: "Trackpad Host", type: "_trackpad-host._tcp", domain: "local.", interface: nil))
}

@Test func connectionConfigurationAcceptsBonjourAddress() {
    let configuration = TrackpadConnectionConfiguration(
        address: .bonjour(name: "Trackpad Host", type: "_trackpad-host._tcp", domain: "local."),
        pairingCode: "123456",
        deviceId: "ios-1",
        deviceName: "iPhone"
    )

    #expect(configuration.address == .bonjour(name: "Trackpad Host", type: "_trackpad-host._tcp", domain: "local."))
    #expect(configuration.host == "Trackpad Host")
    #expect(configuration.port == 0)
}
