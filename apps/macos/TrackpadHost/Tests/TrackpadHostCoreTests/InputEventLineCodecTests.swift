import Foundation
import Testing
import TrackpadKit
@testable import TrackpadHostCore

@Test func lineCodecEncodesOneEventAsNewlineTerminatedJSON() throws {
    let event = InputEvent(
        sequenceNumber: 10,
        timestampNanos: 100,
        kind: .pointerMove(PointerMoveEvent(dx: 1.5, dy: -2))
    )

    let frame = SessionFrame.input(event)
    let data = try InputEventLineCodec.encode(frame)

    var codec = InputEventLineCodec()
    #expect(data.last == UInt8(ascii: "\n"))
    #expect(try codec.append(data) == [frame])
}

@Test func lineCodecWaitsForCompleteLineBeforeDecoding() throws {
    let event = InputEvent(
        sequenceNumber: 11,
        timestampNanos: 101,
        kind: .tap(TapEvent(button: .left))
    )
    let frame = SessionFrame.input(event)
    let data = try InputEventLineCodec.encode(frame)
    let splitIndex = data.index(data.startIndex, offsetBy: data.count / 2)

    var codec = InputEventLineCodec()
    #expect(try codec.append(data[..<splitIndex]) == [])
    #expect(try codec.append(data[splitIndex...]) == [frame])
}

@Test func lineCodecDecodesMultipleFramesFromOneBuffer() throws {
    let first = InputEvent(
        sequenceNumber: 12,
        timestampNanos: 102,
        kind: .pointerButton(PointerButtonEvent(button: .left, phase: .down))
    )
    let second = InputEvent(
        sequenceNumber: 13,
        timestampNanos: 103,
        kind: .scroll(ScrollEvent(dx: 0, dy: -12, phase: .changed))
    )

    let firstFrame = SessionFrame.input(first)
    let secondFrame = SessionFrame.input(second)
    let data = try InputEventLineCodec.encode(firstFrame) + InputEventLineCodec.encode(secondFrame)

    var codec = InputEventLineCodec()
    #expect(try codec.append(data) == [firstFrame, secondFrame])
}
