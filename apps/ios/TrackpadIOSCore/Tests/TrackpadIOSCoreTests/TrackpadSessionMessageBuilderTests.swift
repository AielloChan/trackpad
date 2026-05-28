import Foundation
import Testing
import TrackpadKit
@testable import TrackpadIOSCore

@Test func sessionMessageBuilderCreatesClientHelloFrame() throws {
    let configuration = TrackpadConnectionConfiguration(
        host: "192.168.1.10",
        port: 44787,
        pairingCode: "123456",
        deviceId: "ios-1",
        deviceName: "iPhone",
        trustedClientKey: "known-client-key"
    )

    let data = try TrackpadSessionMessageBuilder.clientHelloData(for: configuration)
    var codec = SessionFrameLineCodec()

    #expect(try codec.append(data) == [
        .clientHello(
            ClientHello(
                protocolVersion: 1,
                deviceId: "ios-1",
                deviceName: "iPhone",
                pairingCode: "123456",
                trustedClientKey: "known-client-key"
            )
        ),
    ])
}

@Test func sessionMessageBuilderCreatesBinaryInputReport() throws {
    let event = InputEvent(
        sequenceNumber: 9,
        timestampNanos: 90,
        kind: .pointerMove(PointerMoveEvent(dx: 7, dy: -1))
    )

    let data = try TrackpadSessionMessageBuilder.inputData(for: event)
    var codec = SessionStreamCodec()

    #expect(data.count == InputReportBinaryCodec.frameLength)
    #expect(data.first == InputReportBinaryCodec.magicByte)
    #expect(try codec.append(data) == [.input(event)])
}

@Test func sessionMessageBuilderCreatesPingFrame() throws {
    let ping = SessionPing(id: 7, clientSentNanos: 700)

    let data = try TrackpadSessionMessageBuilder.pingData(for: ping)
    var codec = SessionFrameLineCodec()

    #expect(try codec.append(data) == [.ping(ping)])
}

@Test func sessionMessageBuilderCreatesClientLogUploadFrame() throws {
    let upload = ClientLogUpload(
        requestId: "request-1",
        deviceId: "ios-1",
        deviceName: "iPad",
        createdAtNanos: 1_000,
        content: "######### ios.client example",
        truncated: false
    )

    let data = try TrackpadSessionMessageBuilder.clientLogUploadData(for: upload)
    var codec = SessionFrameLineCodec()

    #expect(try codec.append(data) == [.clientLogUpload(upload)])
}

@Test func sessionMessageBuilderCreatesScrollMomentumSettingsFrame() throws {
    let settings = ScrollMomentumSettings(
        amount: 1.2,
        decayRate: 0.88,
        tailWindowMilliseconds: 120
    )

    let data = try TrackpadSessionMessageBuilder.scrollMomentumSettingsData(for: settings)
    var codec = SessionFrameLineCodec()

    #expect(try codec.append(data) == [.scrollMomentumSettings(settings)])
}

@Test func sessionMessageBuilderCreatesConfigurationSyncFrame() throws {
    let snapshot = ConfigurationSyncSnapshot(
        revision: 1,
        updatedAtNanos: 100,
        sourceDeviceId: "ios-1",
        configuration: .defaults.withPointerSpeedMultiplier(2.4)
    )

    let data = try TrackpadSessionMessageBuilder.configurationSyncData(for: snapshot)
    var codec = SessionFrameLineCodec()

    #expect(try codec.append(data) == [.configurationSync(snapshot)])
}
