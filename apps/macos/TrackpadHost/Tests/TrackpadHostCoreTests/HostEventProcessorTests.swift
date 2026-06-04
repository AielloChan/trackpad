import Foundation
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

@Test func hostEventProcessorPerformsAndLogsMagnifyCommand() {
    let performer = RecordingInputPerformer()
    let logger = RecordingHostLogger()
    let processor = HostEventProcessor(
        performer: performer,
        logger: logger
    )
    let event = InputEvent(
        sequenceNumber: 23,
        timestampNanos: 203,
        kind: .magnify(MagnifyEvent(magnification: -0.125, phase: .changed))
    )

    processor.handle(event)

    #expect(performer.commands == [
        .magnify(magnification: -0.125, phase: .changed),
    ])
    #expect(logger.messages.contains { $0.contains("input sequence=23 kind=magnify magnification=-0.125 phase=changed") })
    #expect(logger.messages.contains { $0.contains("command magnify magnification=-0.125 phase=changed") })
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

@Test func hostEventProcessorCancelsQueuedMomentumCommandsWhenContactArrivesDuringMomentumExecution() async throws {
    let performer = BlockingMomentumInputPerformer()
    let processor = HostEventProcessor(
        scrollMomentumSynthesizer: MacScrollMomentumSynthesizer(
            settings: ScrollMomentumSettings(amount: 6, decayRate: 0.95, tailWindowMilliseconds: 120),
            maximumStepCount: 8,
            frameIntervalNanos: 1_000_000
        ),
        performer: performer
    )

    processor.handle(InputEvent(
        sequenceNumber: 1,
        timestampNanos: 0,
        kind: .scroll(ScrollEvent(dx: 0, dy: -20, phase: .began))
    ))
    processor.handle(InputEvent(
        sequenceNumber: 2,
        timestampNanos: 16_000_000,
        kind: .scroll(ScrollEvent(dx: 0, dy: -24, phase: .changed))
    ))
    processor.handle(InputEvent(
        sequenceNumber: 3,
        timestampNanos: 32_000_000,
        kind: .scroll(ScrollEvent(dx: 0, dy: 0, phase: .ended))
    ))

    try await performer.waitUntilFirstMomentumCommandStarts()

    let contactTask = Task {
        processor.handle(InputEvent(
            sequenceNumber: 4,
            timestampNanos: 40_000_000,
            kind: .contact(ContactEvent(phase: .began, contactCount: 2))
        ))
    }
    try await Task.sleep(nanoseconds: 5_000_000)
    performer.releaseBlockedMomentumCommand()
    await contactTask.value
    try await Task.sleep(nanoseconds: 50_000_000)

    #expect(performer.momentumCommandCount <= 1)
}

@Test func hostEventProcessorDefersMomentumStartSoImmediateNextContactCanCancelIt() async throws {
    let performer = RecordingInputPerformer()
    let processor = HostEventProcessor(
        scrollMomentumSynthesizer: MacScrollMomentumSynthesizer(
            settings: ScrollMomentumSettings(amount: 6, decayRate: 0.95, tailWindowMilliseconds: 120),
            maximumStepCount: 8,
            frameIntervalNanos: 1_000_000
        ),
        performer: performer
    )

    processor.handle(InputEvent(
        sequenceNumber: 1,
        timestampNanos: 0,
        kind: .scroll(ScrollEvent(dx: 0, dy: -20, phase: .began))
    ))
    processor.handle(InputEvent(
        sequenceNumber: 2,
        timestampNanos: 16_000_000,
        kind: .scroll(ScrollEvent(dx: 0, dy: -24, phase: .changed))
    ))
    processor.handle(InputEvent(
        sequenceNumber: 3,
        timestampNanos: 32_000_000,
        kind: .scroll(ScrollEvent(dx: 0, dy: 0, phase: .ended))
    ))

    processor.handle(InputEvent(
        sequenceNumber: 4,
        timestampNanos: 40_000_000,
        kind: .contact(ContactEvent(phase: .began, contactCount: 2))
    ))
    try await Task.sleep(nanoseconds: 40_000_000)

    #expect(performer.momentumCommandCount == 0)
}

@Test func hostEventProcessorCancelsQueuedMomentumWhenConfigurationDisablesMomentum() async throws {
    let performer = RecordingInputPerformer()
    let processor = HostEventProcessor(
        scrollMomentumSynthesizer: MacScrollMomentumSynthesizer(
            settings: ScrollMomentumSettings(amount: 6, decayRate: 0.95, tailWindowMilliseconds: 120),
            maximumStepCount: 8,
            frameIntervalNanos: 1_000_000
        ),
        performer: performer
    )

    processor.handle(InputEvent(
        sequenceNumber: 1,
        timestampNanos: 0,
        kind: .scroll(ScrollEvent(dx: 0, dy: -20, phase: .began))
    ))
    processor.handle(InputEvent(
        sequenceNumber: 2,
        timestampNanos: 16_000_000,
        kind: .scroll(ScrollEvent(dx: 0, dy: -24, phase: .changed))
    ))
    processor.handle(InputEvent(
        sequenceNumber: 3,
        timestampNanos: 32_000_000,
        kind: .scroll(ScrollEvent(dx: 0, dy: 0, phase: .ended))
    ))

    processor.applyConfiguration(TrackpadConfiguration.defaults.withScrollMomentum(
        ScrollMomentumSettings(isEnabled: false, amount: 6, decayRate: 0.95, tailWindowMilliseconds: 120)
    ))
    try await Task.sleep(nanoseconds: 40_000_000)

    #expect(performer.momentumCommandCount == 0)
}

@Test func hostEventProcessorCancelsMomentumBeforeLoggingContactInput() async throws {
    let performer = RecordingInputPerformer()
    let logger = ContactInputDelayingHostLogger(delayNanos: 40_000_000)
    let processor = HostEventProcessor(
        scrollMomentumSynthesizer: MacScrollMomentumSynthesizer(
            settings: ScrollMomentumSettings(amount: 6, decayRate: 0.95, tailWindowMilliseconds: 120),
            maximumStepCount: 8,
            frameIntervalNanos: 1_000_000
        ),
        performer: performer,
        logger: logger
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
        kind: .contact(ContactEvent(phase: .began, contactCount: 2))
    ))

    try await Task.sleep(nanoseconds: 50_000_000)

    let messages = logger.messages
    let contactIndex = try #require(messages.firstIndex { $0.contains("input sequence=4 kind=contact") })
    let messagesAfterContact = messages[(contactIndex + 1)...]
    #expect(!messagesAfterContact.contains { $0.contains("momentumCommand") })
}

@Test func hostEventProcessorUsesHostClockForScheduledMomentum() async throws {
    let performer = RecordingInputPerformer()
    let clock = IncrementingClock(start: 10_000_000_000, step: 1_000_000)
    let processor = HostEventProcessor(
        scrollMomentumSynthesizer: MacScrollMomentumSynthesizer(
            settings: ScrollMomentumSettings(amount: 6, decayRate: 0.95, tailWindowMilliseconds: 120),
            maximumStepCount: 8,
            frameIntervalNanos: 1_000_000
        ),
        performer: performer,
        nowNanos: clock.now
    )

    processor.handle(InputEvent(
        sequenceNumber: 1,
        timestampNanos: 0,
        kind: .scroll(ScrollEvent(dx: 0, dy: -20, phase: .began))
    ))
    processor.handle(InputEvent(
        sequenceNumber: 2,
        timestampNanos: 16_000_000,
        kind: .scroll(ScrollEvent(dx: 0, dy: -24, phase: .changed))
    ))
    processor.handle(InputEvent(
        sequenceNumber: 3,
        timestampNanos: 32_000_000,
        kind: .scroll(ScrollEvent(dx: 0, dy: 0, phase: .ended))
    ))

    try await Task.sleep(nanoseconds: 60_000_000)

    #expect(performer.changedMomentumCommandCount > 0)
}

private final class RecordingInputPerformer: MacInputPerforming {
    private(set) var commands: [MacInputCommand] = []

    var momentumCommandCount: Int {
        commands.filter { command in
            if case .scroll(_, _, _, let momentumPhase) = command {
                return momentumPhase != nil
            }
            return false
        }.count
    }

    var changedMomentumCommandCount: Int {
        commands.filter { command in
            if case .scroll(_, _, .changed, let momentumPhase) = command {
                return momentumPhase != nil
            }
            return false
        }.count
    }

    func perform(_ command: MacInputCommand) {
        commands.append(command)
    }
}

private final class IncrementingClock: @unchecked Sendable {
    private let lock = NSLock()
    private let step: UInt64
    private var value: UInt64

    init(start: UInt64, step: UInt64) {
        self.value = start
        self.step = step
    }

    func now() -> UInt64 {
        lock.withLock {
            defer { value += step }
            return value
        }
    }
}

private final class RecordingHostLogger: HostLogging, @unchecked Sendable {
    private(set) var messages: [String] = []

    func log(level: HostLogLevel, category: String, message: String) {
        messages.append("[\(level.rawValue)] [\(category)] \(message)")
    }
}

private final class ContactInputDelayingHostLogger: HostLogging, @unchecked Sendable {
    private let lock = NSLock()
    private let delayNanos: UInt64
    private(set) var messages: [String] = []

    init(delayNanos: UInt64) {
        self.delayNanos = delayNanos
    }

    func log(level: HostLogLevel, category: String, message: String) {
        lock.withLock {
            messages.append("[\(level.rawValue)] [\(category)] \(message)")
        }

        if message.contains("input sequence=4 kind=contact") {
            Thread.sleep(forTimeInterval: Double(delayNanos) / 1_000_000_000)
        }
    }
}

private final class BlockingMomentumInputPerformer: MacInputPerforming, @unchecked Sendable {
    private let lock = NSLock()
    private let releaseFirstMomentum = DispatchSemaphore(value: 0)
    private var firstMomentumStarted = false
    private var hasBlockedFirstMomentum = false
    private(set) var commands: [MacInputCommand] = []

    var momentumCommandCount: Int {
        lock.withLock {
            commands.filter { command in
                if case .scroll(_, _, _, let momentumPhase) = command {
                    return momentumPhase != nil
                }
                return false
            }.count
        }
    }

    func perform(_ command: MacInputCommand) {
        var shouldBlock = false
        lock.withLock {
            commands.append(command)
            if case .scroll(_, _, _, let momentumPhase) = command,
               momentumPhase != nil,
               !hasBlockedFirstMomentum {
                hasBlockedFirstMomentum = true
                firstMomentumStarted = true
                shouldBlock = true
            }
        }

        if shouldBlock {
            releaseFirstMomentum.wait()
        }
    }

    func waitUntilFirstMomentumCommandStarts() async throws {
        for _ in 0..<100 {
            if lock.withLock({ firstMomentumStarted }) {
                return
            }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
    }

    func releaseBlockedMomentumCommand() {
        releaseFirstMomentum.signal()
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
