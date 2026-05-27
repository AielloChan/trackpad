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
        deviceName: "iPhone"
    )

    let data = try TrackpadSessionMessageBuilder.clientHelloData(for: configuration)
    var codec = SessionFrameLineCodec()

    #expect(try codec.append(data) == [
        .clientHello(
            ClientHello(
                protocolVersion: 1,
                deviceId: "ios-1",
                deviceName: "iPhone",
                pairingCode: "123456"
            )
        ),
    ])
}

@Test func sessionMessageBuilderCreatesInputFrame() throws {
    let event = InputEvent(
        sequenceNumber: 9,
        timestampNanos: 90,
        kind: .pointerMove(PointerMoveEvent(dx: 7, dy: -1))
    )

    let data = try TrackpadSessionMessageBuilder.inputData(for: event)
    var codec = SessionFrameLineCodec()

    #expect(try codec.append(data) == [.input(event)])
}

@Test func sessionMessageBuilderCreatesPingFrame() throws {
    let ping = SessionPing(id: 7, clientSentNanos: 700)

    let data = try TrackpadSessionMessageBuilder.pingData(for: ping)
    var codec = SessionFrameLineCodec()

    #expect(try codec.append(data) == [.ping(ping)])
}
