import Foundation
import Testing
import TrackpadKit
@testable import TrackpadIOSCore

@Test func trustedHostStorePersistsClientKeyForReconnect() throws {
    let fileURL = temporaryTrustedHostFileURL()
    let store = TrustedHostStore(fileURL: fileURL)
    let configuration = TrackpadConnectionConfiguration(
        host: "192.168.1.10",
        port: 44787,
        pairingCode: "123456",
        deviceId: "ios-1",
        deviceName: "Alice iPad"
    )
    let key = TrustedClientKey(
        deviceId: "ios-1",
        clientKey: "client-key",
        issuedAtNanos: 1_000
    )

    try store.save(key, for: configuration, timestampNanos: 1_500)

    #expect(try store.clientKey(for: configuration, timestampNanos: 2_000) == "client-key")

    let storedLines = try String(contentsOf: fileURL, encoding: .utf8)
        .split(separator: "\n")
    let storedLine = try #require(storedLines.first)
    let record = try JSONDecoder().decode(TrustedHostRecord.self, from: Data(storedLine.utf8))

    #expect(record.id == "192.168.1.10:44787")
    #expect(record.host == "192.168.1.10")
    #expect(record.port == 44787)
    #expect(record.deviceId == "ios-1")
    #expect(record.firstAuthorizedAtNanos == 1_000)
    #expect(record.lastUsedAtNanos == 2_000)
}

@Test func trustedHostStorePersistsQRCodeKeyForBonjourReconnect() throws {
    let fileURL = temporaryTrustedHostFileURL()
    let store = TrustedHostStore(fileURL: fileURL)
    let qrConfiguration = TrackpadConnectionConfiguration(
        host: "192.168.3.183",
        port: 44787,
        pairingCode: "123456",
        deviceId: "ios-1",
        deviceName: "Alice iPhone",
        trustedHostAliases: ["bonjour:Trackpad Host"]
    )
    let bonjourConfiguration = TrackpadConnectionConfiguration(
        address: .bonjour(
            name: "Trackpad Host",
            type: TrackpadDiscoveryDefaults.bonjourType,
            domain: TrackpadDiscoveryDefaults.bonjourDomain
        ),
        pairingCode: "",
        deviceId: "ios-1",
        deviceName: "Alice iPhone"
    )
    let key = TrustedClientKey(
        deviceId: "ios-1",
        clientKey: "client-key",
        issuedAtNanos: 1_000
    )

    try store.save(key, for: qrConfiguration, timestampNanos: 1_500)

    #expect(try store.clientKey(for: bonjourConfiguration, timestampNanos: 2_000) == "client-key")
}

@Test func trustedHostStoreMigratesSingleLegacyManualRecordForBonjourReconnect() throws {
    let fileURL = temporaryTrustedHostFileURL()
    let store = TrustedHostStore(fileURL: fileURL)
    let legacyConfiguration = TrackpadConnectionConfiguration(
        host: "192.168.3.183",
        port: 44787,
        pairingCode: "123456",
        deviceId: "ios-1",
        deviceName: "Alice iPhone"
    )
    let bonjourConfiguration = TrackpadConnectionConfiguration(
        address: .bonjour(
            name: "Trackpad Host",
            type: TrackpadDiscoveryDefaults.bonjourType,
            domain: TrackpadDiscoveryDefaults.bonjourDomain
        ),
        pairingCode: "",
        deviceId: "ios-1",
        deviceName: "Alice iPhone"
    )
    let key = TrustedClientKey(
        deviceId: "ios-1",
        clientKey: "legacy-client-key",
        issuedAtNanos: 1_000
    )

    try store.save(key, for: legacyConfiguration, timestampNanos: 1_500)

    #expect(try store.clientKey(for: bonjourConfiguration, timestampNanos: 2_000) == "legacy-client-key")
    #expect(try store.clientKey(for: bonjourConfiguration, timestampNanos: 2_500) == "legacy-client-key")
}

private func temporaryTrustedHostFileURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathComponent("trusted_hosts.jsonl")
}
