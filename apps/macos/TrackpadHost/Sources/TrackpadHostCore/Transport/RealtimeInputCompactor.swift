import Foundation
import TrackpadKit

struct RealtimeInputCompactor {
    private let maxRealtimeAgeNanos: UInt64

    init(maxRealtimeAgeNanos: UInt64 = 50_000_000) {
        self.maxRealtimeAgeNanos = maxRealtimeAgeNanos
    }

    func compact(_ messages: [SessionStreamMessage]) -> [SessionStreamMessage] {
        var compacted: [SessionStreamMessage] = []
        var pendingInputs: [InputEvent] = []

        for message in messages {
            switch message {
            case .input(let event):
                pendingInputs.append(event)
            case .frame:
                flush(pendingInputs, into: &compacted)
                pendingInputs.removeAll(keepingCapacity: true)
                compacted.append(message)
            }
        }

        flush(pendingInputs, into: &compacted)
        return compacted
    }

    private func flush(_ inputs: [InputEvent], into messages: inout [SessionStreamMessage]) {
        guard !inputs.isEmpty else {
            return
        }

        let newestTimestamp = inputs.map(\.timestampNanos).max()
        var compactedInputs: [InputEvent] = []
        for event in inputs {
            if shouldDrop(event, newestTimestamp: newestTimestamp) {
                continue
            }

            if let last = compactedInputs.last,
               let coalesced = last.coalesced(with: event) {
                compactedInputs[compactedInputs.count - 1] = coalesced
            } else {
                compactedInputs.append(event)
            }
        }

        messages.append(contentsOf: compactedInputs.map(SessionStreamMessage.input))
    }

    private func shouldDrop(_ event: InputEvent, newestTimestamp: UInt64?) -> Bool {
        guard event.isDroppableRealtimeEvent,
              let newestTimestamp,
              newestTimestamp > event.timestampNanos else {
            return false
        }

        return newestTimestamp - event.timestampNanos > maxRealtimeAgeNanos
    }
}

private extension InputEvent {
    var isDroppableRealtimeEvent: Bool {
        switch kind {
        case .pointerMove:
            return true
        case .scroll(let scroll):
            return scroll.phase == .changed
        case .pointerButton, .tap, .systemAction:
            return false
        }
    }

    func coalesced(with next: InputEvent) -> InputEvent? {
        switch (kind, next.kind) {
        case (.pointerMove(let move), .pointerMove(let nextMove)):
            return InputEvent(
                sequenceNumber: next.sequenceNumber,
                timestampNanos: next.timestampNanos,
                kind: .pointerMove(PointerMoveEvent(
                    dx: move.dx + nextMove.dx,
                    dy: move.dy + nextMove.dy
                ))
            )
        case (.scroll(let scroll), .scroll(let nextScroll))
            where scroll.phase == .changed
                && nextScroll.phase == .changed
                && scroll.momentumPhase == nextScroll.momentumPhase:
            return InputEvent(
                sequenceNumber: next.sequenceNumber,
                timestampNanos: next.timestampNanos,
                kind: .scroll(ScrollEvent(
                    dx: scroll.dx + nextScroll.dx,
                    dy: scroll.dy + nextScroll.dy,
                    phase: nextScroll.phase,
                    momentumPhase: nextScroll.momentumPhase
                ))
            )
        default:
            return nil
        }
    }
}
