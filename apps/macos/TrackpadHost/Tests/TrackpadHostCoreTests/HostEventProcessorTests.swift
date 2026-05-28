import Testing
import TrackpadKit
@testable import TrackpadHostCore

@Test func hostEventProcessorPerformsPointerMoveCommand() {
    let performer = RecordingInputPerformer()
    let processor = HostEventProcessor(performer: performer)
    let event = InputEvent(
        sequenceNumber: 20,
        timestampNanos: 200,
        kind: .pointerMove(PointerMoveEvent(dx: 3, dy: -4))
    )

    processor.handle(event)

    #expect(performer.commands == [.move(dx: 3, dy: -4)])
    #expect(processor.handledEventCount == 1)
}

@Test func hostEventProcessorPerformsTapDownAndUpCommands() {
    let performer = RecordingInputPerformer()
    let processor = HostEventProcessor(performer: performer)
    let event = InputEvent(
        sequenceNumber: 21,
        timestampNanos: 201,
        kind: .tap(TapEvent(button: .right))
    )

    processor.handle(event)

    #expect(performer.commands == [
        .button(button: .right, phase: .down, clickCount: 1),
        .button(button: .right, phase: .up, clickCount: 1),
    ])
    #expect(processor.handledEventCount == 1)
}

@Test func hostEventProcessorLogsInputEventsAndMappedCommands() {
    let performer = RecordingInputPerformer()
    let logger = RecordingHostLogger()
    let processor = HostEventProcessor(
        performer: performer,
        logger: logger
    )
    let event = InputEvent(
        sequenceNumber: 22,
        timestampNanos: 202,
        kind: .scroll(ScrollEvent(dx: 4, dy: -8, phase: .changed, momentumPhase: .changed))
    )

    processor.handle(event)

    #expect(logger.messages.contains { $0.contains("input sequence=22 kind=scroll dx=4.0 dy=-8.0 phase=changed momentum=changed") })
    #expect(logger.messages.contains { $0.contains("command scroll dx=4.0 dy=-8.0 phase=changed momentum=changed") })
}

@Test func hostEventProcessorCancelsScheduledScrollMomentumOnContactBegin() async throws {
    let performer = RecordingInputPerformer()
    let processor = HostEventProcessor(
        scrollMomentumSynthesizer: MacScrollMomentumSynthesizer(
            settings: ScrollMomentumSettings(amount: 6, decayRate: 0.95, tailWindowMilliseconds: 120),
            frameIntervalNanos: 20_000_000
        ),
        performer: performer
    )

    processor.handle(InputEvent(
        sequenceNumber: 1,
        timestampNanos: 0,
        kind: .scroll(ScrollEvent(dx: 0, dy: 20, phase: .began))
    ))
    processor.handle(InputEvent(
        sequenceNumber: 2,
        timestampNanos: 16_000_000,
        kind: .scroll(ScrollEvent(dx: 0, dy: 24, phase: .changed))
    ))
    processor.handle(InputEvent(
        sequenceNumber: 3,
        timestampNanos: 32_000_000,
        kind: .scroll(ScrollEvent(dx: 0, dy: 0, phase: .ended))
    ))
    processor.handle(InputEvent(
        sequenceNumber: 4,
        timestampNanos: 40_000_000,
        kind: .contact(ContactEvent(phase: .began, contactCount: 1))
    ))

    try await Task.sleep(nanoseconds: 80_000_000)

    #expect(performer.commands == [
        .scroll(dx: 0, dy: 20, phase: .began, momentumPhase: nil),
        .scroll(dx: 0, dy: 24, phase: .changed, momentumPhase: nil),
        .scroll(dx: 0, dy: 0, phase: .ended, momentumPhase: nil),
    ])
}

private final class RecordingInputPerformer: MacInputPerforming {
    private(set) var commands: [MacInputCommand] = []

    func perform(_ command: MacInputCommand) {
        commands.append(command)
    }
}

private final class RecordingHostLogger: HostLogging, @unchecked Sendable {
    private(set) var messages: [String] = []

    func log(level: HostLogLevel, category: String, message: String) {
        messages.append("[\(level.rawValue)] [\(category)] \(message)")
    }
}
