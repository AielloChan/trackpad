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
