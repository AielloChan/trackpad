import Foundation
import Testing
import TrackpadKit
@testable import TrackpadHostCore

@Test func authorizedClientStorePersistsAndValidatesTrustedClientKey() throws {
    let fileURL = temporaryAuthorizedClientFileURL()
    let store = AuthorizedClientStore(fileURL: fileURL)
    let hello = ClientHello(
        protocolVersion: 1,
        deviceId: "ios-1",
        deviceName: "Alice iPad",
        pairingCode: "654321"
    )

    let credential = try store.authorize(
        hello,
        remoteAddress: "192.168.1.20",
        timestampNanos: 1_000
    )
    let trustedHello = ClientHello(
        protocolVersion: 1,
        deviceId: "ios-1",
        deviceName: "Alice iPad",
        pairingCode: "000000",
        trustedClientKey: credential.clientKey
    )

    #expect(try store.validate(trustedHello, remoteAddress: "192.168.1.30", timestampNanos: 2_000))

    let storedLines = try String(contentsOf: fileURL, encoding: .utf8)
        .split(separator: "\n")
    let latestRecord = try #require(storedLines.last)
    let decoded = try JSONDecoder().decode(AuthorizedClientRecord.self, from: Data(latestRecord.utf8))

    #expect(decoded.id == "ios-1")
    #expect(decoded.deviceId == "ios-1")
    #expect(decoded.deviceName == "Alice iPad")
    #expect(decoded.firstAuthorizedAtNanos == 1_000)
    #expect(decoded.lastAuthorizedAtNanos == 2_000)
    #expect(decoded.firstRemoteAddress == "192.168.1.20")
    #expect(decoded.lastRemoteAddress == "192.168.1.30")
    #expect(decoded.clientKeyHash != credential.clientKey)
}

@Test func authorizedClientStoreRejectsWrongTrustedClientKey() throws {
    let fileURL = temporaryAuthorizedClientFileURL()
    let store = AuthorizedClientStore(fileURL: fileURL)
    let hello = ClientHello(
        protocolVersion: 1,
        deviceId: "ios-1",
        deviceName: "Alice iPad",
        pairingCode: "654321"
    )

    _ = try store.authorize(hello, remoteAddress: "192.168.1.20", timestampNanos: 1_000)

    let wrongHello = ClientHello(
        protocolVersion: 1,
        deviceId: "ios-1",
        deviceName: "Alice iPad",
        pairingCode: "000000",
        trustedClientKey: "wrong-key"
    )

    #expect(try store.validate(wrongHello, remoteAddress: "192.168.1.20", timestampNanos: 2_000) == false)
}

private func temporaryAuthorizedClientFileURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathComponent("authorized_clients.jsonl")
}
