import Testing
import TrackpadKit
@testable import TrackpadIOSCore

@Test func sendBufferDrainsFirstBatchAndCoalescesPendingPointerReports() {
    var buffer = InputReportSendBuffer()
    let first = inputReport(sequence: 1, dx: 1, dy: 2)
    let second = inputReport(sequence: 2, dx: 3, dy: 4)
    let third = inputReport(sequence: 3, dx: -1, dy: 5)

    #expect(buffer.enqueue([first]) == [first])
    #expect(buffer.enqueue([second]) == nil)
    #expect(buffer.enqueue([third]) == nil)
    #expect(buffer.completeCurrentSend() == [
        inputReport(sequence: 3, dx: 2, dy: 9),
    ])
    #expect(buffer.completeCurrentSend() == nil)
}

@Test func sendBufferIgnoresEmptyBatches() {
    var buffer = InputReportSendBuffer()

    #expect(buffer.enqueue([]) == nil)
    #expect(buffer.completeCurrentSend() == nil)
}

@Test func sendBufferDoesNotCoalesceAcrossButtonBoundaries() {
    var buffer = InputReportSendBuffer()
    let button = InputReport(
        sequenceNumber: 3,
        timestampNanos: 3,
        kind: .pointerButton(button: .left, phase: .down)
    )

    #expect(buffer.enqueue([inputReport(sequence: 1, dx: 1, dy: 0)]) == [
        inputReport(sequence: 1, dx: 1, dy: 0),
    ])
    #expect(buffer.enqueue([
        inputReport(sequence: 2, dx: 2, dy: 0),
        button,
        inputReport(sequence: 4, dx: 4, dy: 0),
    ]) == nil)

    #expect(buffer.completeCurrentSend() == [
        inputReport(sequence: 2, dx: 2, dy: 0),
        button,
        inputReport(sequence: 4, dx: 4, dy: 0),
    ])
}

@Test func sendBufferDoesNotCoalesceDragStartupPointerReports() {
    var buffer = InputReportSendBuffer()
    let button = InputReport(
        sequenceNumber: 1,
        timestampNanos: 1,
        kind: .pointerButton(button: .left, phase: .down)
    )

    #expect(buffer.enqueue([button]) == [button])
    #expect(buffer.enqueue([inputReport(sequence: 2, dx: 3, dy: 0)]) == nil)
    #expect(buffer.enqueue([inputReport(sequence: 3, dx: 3, dy: 0)]) == nil)
    #expect(buffer.enqueue([inputReport(sequence: 4, dx: 3, dy: 0)]) == nil)
    #expect(buffer.completeCurrentSend() == [
        inputReport(sequence: 2, dx: 3, dy: 0),
        inputReport(sequence: 3, dx: 3, dy: 0),
        inputReport(sequence: 4, dx: 3, dy: 0),
    ])
}

@Test func sendBufferDoesNotCoalescePointerStartupReportsAfterContactBegin() {
    var buffer = InputReportSendBuffer()
    let contact = InputReport(
        sequenceNumber: 1,
        timestampNanos: 1,
        kind: .contact(phase: .began, contactCount: 1)
    )

    #expect(buffer.enqueue([contact]) == [contact])
    #expect(buffer.enqueue([inputReport(sequence: 2, dx: 3, dy: 0)]) == nil)
    #expect(buffer.enqueue([inputReport(sequence: 3, dx: 3, dy: 0)]) == nil)
    #expect(buffer.completeCurrentSend() == [
        inputReport(sequence: 2, dx: 3, dy: 0),
        inputReport(sequence: 3, dx: 3, dy: 0),
    ])
}

@Test func sendBufferDropsStaleRealtimeReportsButKeepsBoundaryReports() {
    var buffer = InputReportSendBuffer(maxPendingReportAgeNanos: 10)
    let button = InputReport(
        sequenceNumber: 3,
        timestampNanos: 105,
        kind: .pointerButton(button: .left, phase: .down)
    )

    #expect(buffer.enqueue([inputReport(sequence: 1, dx: 1, dy: 0)]) == [
        inputReport(sequence: 1, dx: 1, dy: 0),
    ])
    #expect(buffer.enqueue([
        inputReport(sequence: 2, dx: 2, dy: 0),
        button,
        inputReport(sequence: 4, timestamp: 120, dx: 4, dy: 0),
    ]) == nil)

    #expect(buffer.completeCurrentSend(currentTimestampNanos: 120) == [
        button,
        inputReport(sequence: 4, timestamp: 120, dx: 4, dy: 0),
    ])
}

@Test func sendBufferKeepsContactReportsUnderBackpressure() {
    var buffer = InputReportSendBuffer(maxPendingReportAgeNanos: 10)
    let contact = InputReport(
        sequenceNumber: 3,
        timestampNanos: 105,
        kind: .contact(phase: .began, contactCount: 1)
    )

    #expect(buffer.enqueue([inputReport(sequence: 1, dx: 1, dy: 0)]) == [
        inputReport(sequence: 1, dx: 1, dy: 0),
    ])
    #expect(buffer.enqueue([
        inputReport(sequence: 2, dx: 2, dy: 0),
        contact,
        inputReport(sequence: 4, timestamp: 120, dx: 4, dy: 0),
    ]) == nil)

    #expect(buffer.completeCurrentSend(currentTimestampNanos: 120) == [
        contact,
        inputReport(sequence: 4, timestamp: 120, dx: 4, dy: 0),
    ])
}

@Test func sendBufferDropsOldestRealtimeReportsWhenPendingBacklogExceedsLimit() {
    var buffer = InputReportSendBuffer(maxPendingReportAgeNanos: 1_000, maxPendingReportCount: 2)
    let button = InputReport(
        sequenceNumber: 3,
        timestampNanos: 3,
        kind: .pointerButton(button: .left, phase: .down)
    )

    #expect(buffer.enqueue([inputReport(sequence: 1, dx: 1, dy: 0)]) == [
        inputReport(sequence: 1, dx: 1, dy: 0),
    ])
    #expect(buffer.enqueue([
        inputReport(sequence: 2, dx: 2, dy: 0),
        button,
        inputReport(sequence: 4, dx: 4, dy: 0),
    ]) == nil)

    #expect(buffer.completeCurrentSend(currentTimestampNanos: 4) == [
        button,
        inputReport(sequence: 4, dx: 4, dy: 0),
    ])
}

private func inputReport(sequence: UInt64, dx: Double, dy: Double) -> InputReport {
    inputReport(sequence: sequence, timestamp: sequence, dx: dx, dy: dy)
}

private func inputReport(sequence: UInt64, timestamp: UInt64, dx: Double, dy: Double) -> InputReport {
    InputReport(
        sequenceNumber: sequence,
        timestampNanos: timestamp,
        kind: .pointerMove(dx: dx, dy: dy)
    )
}
