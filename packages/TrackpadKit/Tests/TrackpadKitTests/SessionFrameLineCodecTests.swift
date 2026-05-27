import Foundation
import Testing
@testable import TrackpadKit

@Test func sessionFrameLineCodecEncodesNewlineTerminatedFrame() throws {
    let frame = SessionFrame.clientHello(
        ClientHello(
            protocolVersion: 1,
            deviceId: "ios-device",
            deviceName: "iPhone",
            pairingCode: "123456"
        )
    )

    let data = try SessionFrameLineCodec.encode(frame)

    #expect(data.last == UInt8(ascii: "\n"))
}

@Test func sessionFrameLineCodecWaitsForCompleteLine() throws {
    let frame = SessionFrame.input(
        InputEvent(
            sequenceNumber: 1,
            timestampNanos: 10,
            kind: .pointerMove(PointerMoveEvent(dx: 4, dy: -2))
        )
    )
    let data = try SessionFrameLineCodec.encode(frame)
    let splitIndex = data.index(data.startIndex, offsetBy: data.count / 2)

    var codec = SessionFrameLineCodec()

    #expect(try codec.append(data[..<splitIndex]) == [])
    #expect(try codec.append(data[splitIndex...]) == [frame])
}

@Test func sessionFrameLineCodecDecodesMultipleFrames() throws {
    let first = SessionFrame.clientHello(
        ClientHello(
            protocolVersion: 1,
            deviceId: "ios-device",
            deviceName: "iPhone",
            pairingCode: "123456"
        )
    )
    let second = SessionFrame.input(
        InputEvent(
            sequenceNumber: 2,
            timestampNanos: 20,
            kind: .pointerMove(PointerMoveEvent(dx: 5, dy: 3))
        )
    )
    let data = try SessionFrameLineCodec.encode(first) + SessionFrameLineCodec.encode(second)

    var codec = SessionFrameLineCodec()

    #expect(try codec.append(data) == [first, second])
}
