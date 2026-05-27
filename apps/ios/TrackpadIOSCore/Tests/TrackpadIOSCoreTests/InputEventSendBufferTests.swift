import Foundation
import Testing
@testable import TrackpadIOSCore

@Test func sendBufferDrainsFirstBatchAndCoalescesPendingBatches() {
    var buffer = InputEventSendBuffer()

    #expect(buffer.enqueue(Data([1, 2])) == Data([1, 2]))
    #expect(buffer.enqueue(Data([3])) == nil)
    #expect(buffer.enqueue(Data([4, 5])) == nil)
    #expect(buffer.completeCurrentSend() == Data([3, 4, 5]))
    #expect(buffer.completeCurrentSend() == nil)
}

@Test func sendBufferIgnoresEmptyBatches() {
    var buffer = InputEventSendBuffer()

    #expect(buffer.enqueue(Data()) == nil)
    #expect(buffer.completeCurrentSend() == nil)
}
