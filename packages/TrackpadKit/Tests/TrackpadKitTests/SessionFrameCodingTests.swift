import Foundation
import Testing
@testable import TrackpadKit

@Test func clientHelloFrameRoundTripsThroughJSON() throws {
    let frame = SessionFrame.clientHello(
        ClientHello(
            protocolVersion: 1,
            deviceId: "ios-device-1",
            deviceName: "iPhone",
            pairingCode: "123456"
        )
    )

    let data = try JSONEncoder().encode(frame)
    let decoded = try JSONDecoder().decode(SessionFrame.self, from: data)

    #expect(decoded == frame)
}

@Test func inputFrameRoundTripsThroughJSON() throws {
    let event = InputEvent(
        sequenceNumber: 1,
        timestampNanos: 100,
        kind: .pointerMove(PointerMoveEvent(dx: 10, dy: -2))
    )
    let frame = SessionFrame.input(event)

    let data = try JSONEncoder().encode(frame)
    let decoded = try JSONDecoder().decode(SessionFrame.self, from: data)

    #expect(decoded == frame)
}

@Test func rejectedFrameRoundTripsThroughJSON() throws {
    let frame = SessionFrame.rejected(
        SessionRejected(reason: "invalid pairing code")
    )

    let data = try JSONEncoder().encode(frame)
    let decoded = try JSONDecoder().decode(SessionFrame.self, from: data)

    #expect(decoded == frame)
}

@Test func pingFrameRoundTripsThroughJSON() throws {
    let frame = SessionFrame.ping(SessionPing(id: 42, clientSentNanos: 1_000))

    let data = try JSONEncoder().encode(frame)
    let decoded = try JSONDecoder().decode(SessionFrame.self, from: data)

    #expect(decoded == frame)
}

@Test func pongFrameRoundTripsThroughJSON() throws {
    let frame = SessionFrame.pong(SessionPong(id: 42, clientSentNanos: 1_000, hostReceivedNanos: 2_000))

    let data = try JSONEncoder().encode(frame)
    let decoded = try JSONDecoder().decode(SessionFrame.self, from: data)

    #expect(decoded == frame)
}

@Test func hostLogRequestFrameRoundTripsThroughJSON() throws {
    let frame = SessionFrame.hostLogRequest(
        HostLogRequest(id: "request-1", requestedAtNanos: 1_000, reason: "debug pointer jump")
    )

    let data = try JSONEncoder().encode(frame)
    let decoded = try JSONDecoder().decode(SessionFrame.self, from: data)

    #expect(decoded == frame)
}

@Test func clientLogUploadFrameRoundTripsThroughJSON() throws {
    let frame = SessionFrame.clientLogUpload(
        ClientLogUpload(
            requestId: "request-1",
            deviceId: "ios-device-1",
            deviceName: "iPad",
            createdAtNanos: 2_000,
            content: "######### ios.client example",
            truncated: false
        )
    )

    let data = try JSONEncoder().encode(frame)
    let decoded = try JSONDecoder().decode(SessionFrame.self, from: data)

    #expect(decoded == frame)
}
