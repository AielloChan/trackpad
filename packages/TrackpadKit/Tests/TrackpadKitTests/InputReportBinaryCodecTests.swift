import Foundation
import Testing
@testable import TrackpadKit

@Test func pointerMoveReportEncodesAsFixedSizeBinaryFrame() throws {
    let event = InputEvent(
        sequenceNumber: 7,
        timestampNanos: 1_000,
        kind: .pointerMove(PointerMoveEvent(dx: 1.25, dy: -0.5))
    )

    let report = try InputReport(event: event)
    let data = try InputReportBinaryCodec.encode(report)
    let decoded = try InputReportBinaryCodec.decode(data)

    #expect(data.count == InputReportBinaryCodec.frameLength)
    #expect(data.first == InputReportBinaryCodec.magicByte)
    #expect(decoded.inputEvent == event)
}

@Test func scrollReportPreservesPhaseAndMomentumPhase() throws {
    let event = InputEvent(
        sequenceNumber: 8,
        timestampNanos: 1_100,
        kind: .scroll(ScrollEvent(dx: 0, dy: -12.75, phase: .changed, momentumPhase: .changed))
    )

    let decoded = try InputReportBinaryCodec.decode(InputReportBinaryCodec.encode(try InputReport(event: event)))

    #expect(decoded.inputEvent == event)
}

@Test func mixedSessionStreamDecodesJsonControlFramesAndBinaryInputReports() throws {
    let hello = SessionFrame.clientHello(
        ClientHello(
            protocolVersion: 1,
            deviceId: "ios-device-1",
            deviceName: "iPad",
            pairingCode: "123456"
        )
    )
    let event = InputEvent(
        sequenceNumber: 9,
        timestampNanos: 1_200,
        kind: .pointerMove(PointerMoveEvent(dx: -2, dy: 3))
    )

    var data = try SessionFrameLineCodec.encode(hello)
    data.append(try InputReportBinaryCodec.encode(try InputReport(event: event)))

    var codec = SessionStreamCodec()
    let messages = try codec.append(data)

    #expect(messages == [
        .frame(hello),
        .input(event),
    ])
}
