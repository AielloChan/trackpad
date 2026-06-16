import Foundation
import TrackpadKit

public final class HostEventProcessor: @unchecked Sendable {
    private var mapper: MacInputMapper
    private var scrollMomentumSynthesizer: MacScrollMomentumSynthesizer
    private let performer: MacInputPerforming
    private let logger: any HostLogging
    private let momentumQueue = DispatchQueue(label: "trackpad.host.scroll-momentum", qos: .userInteractive)
    private let momentumGenerationLock = NSLock()
    private let momentumExecutionLock = NSLock()
    private let nowNanos: @Sendable () -> UInt64
    private var momentumGeneration: UInt64 = 0
    private let minimumMomentumStartGuardNanos: UInt64 = 20_000_000
    private let maximumMomentumStartGuardNanos: UInt64 = 35_000_000

    public private(set) var configuration: TrackpadConfiguration
    public private(set) var handledEventCount = 0

    public init(
        mapper: MacInputMapper = MacInputMapper(),
        scrollMomentumSynthesizer: MacScrollMomentumSynthesizer = MacScrollMomentumSynthesizer(),
        configuration: TrackpadConfiguration = .defaults,
        performer: MacInputPerforming,
        logger: any HostLogging = DisabledHostLogger(),
        nowNanos: (@Sendable () -> UInt64)? = nil
    ) {
        self.mapper = mapper
        self.scrollMomentumSynthesizer = scrollMomentumSynthesizer
        self.configuration = configuration
        self.performer = performer
        self.logger = logger
        self.nowNanos = nowNanos ?? { DispatchTime.now().uptimeNanoseconds }
        self.scrollMomentumSynthesizer.updateSettings(configuration.scrollMomentum)
    }

    public func applyConfiguration(_ configuration: TrackpadConfiguration) {
        self.configuration = configuration
        scrollMomentumSynthesizer.updateSettings(configuration.scrollMomentum)
        if !configuration.scrollMomentum.isEnabled {
            cancelScheduledMomentum()
        }
        logger.info(category: "config", "applied pointer=\(configuration.pointer.speedMultiplier) pointerMax=\(configuration.pointer.accelerationMaximumMultiplier) pointerStart=\(configuration.pointer.accelerationStartVelocity) pointerEnd=\(configuration.pointer.accelerationEndVelocity) momentumEnabled=\(configuration.scrollMomentum.isEnabled) momentum=\(configuration.scrollMomentum.amount) decay=\(configuration.scrollMomentum.decayRate) tailMs=\(configuration.scrollMomentum.tailWindowMilliseconds)")
    }

    public func updateScrollMomentumSettings(_ settings: ScrollMomentumSettings) {
        applyConfiguration(configuration.withScrollMomentum(settings))
    }

    public func handle(_ event: InputEvent) {
        if shouldCancelScheduledMomentum(for: event) {
            cancelScheduledMomentum()
        }
        logger.debug(category: "input", "input sequence=\(event.sequenceNumber) \(event.logSummary)")

        let commands = mapper.commands(for: event)
        for command in commands {
            logger.debug(category: "input", "command \(command.logSummary)")
            performer.perform(command)
        }

        let didStartMomentum = momentumExecutionLock.withLock {
            let didStart = scrollMomentumSynthesizer.handle(event)
            if didStart {
                scrollMomentumSynthesizer.startMomentumClock(at: nowNanos())
            }
            return didStart
        }
        scheduleMomentumIfNeeded(didStartMomentum)
        handledEventCount += 1
    }

    private func shouldCancelScheduledMomentum(for event: InputEvent) -> Bool {
        switch event.kind {
        case .scroll(let scroll):
            return scroll.momentumPhase == nil
        case .pointerMove, .pointerButton, .tap, .magnify, .systemAction, .contact:
            return true
        }
    }

    private func cancelScheduledMomentum() {
        _ = nextMomentumGeneration()
        momentumExecutionLock.withLock {
            scrollMomentumSynthesizer.cancelMomentum()
        }
    }

    private func scheduleMomentumIfNeeded(_ didStartMomentum: Bool) {
        guard didStartMomentum else {
            return
        }

        let frameIntervalNanos = scrollMomentumSynthesizer.frameIntervalNanos
        let startGuardNanos = momentumStartGuardNanos(frameIntervalNanos: frameIntervalNanos)
        let generation = nextMomentumGeneration()
        scheduleNextMomentumFrame(generation: generation, delayNanos: startGuardNanos + frameIntervalNanos)
    }

    private func scheduleNextMomentumFrame(generation: UInt64, delayNanos: UInt64) {
        momentumQueue.asyncAfter(deadline: .now() + .nanoseconds(Int(min(delayNanos, UInt64(Int.max))))) {
            self.performScheduledMomentumFrame(generation: generation)
        }
    }

    private func performScheduledMomentumFrame(generation: UInt64) {
        let command = momentumExecutionLock.withLock {
            guard isCurrentMomentumGeneration(generation) else {
                return nil as MacInputCommand?
            }

            return scrollMomentumSynthesizer.nextMomentumCommand(at: nowNanos())
        }

        guard let command else {
            if isCurrentMomentumGeneration(generation) {
                scheduleNextMomentumFrame(generation: generation, delayNanos: scrollMomentumSynthesizer.frameIntervalNanos)
            }
            return
        }

        momentumExecutionLock.withLock {
            guard isCurrentMomentumGeneration(generation) else {
                return
            }

            logger.debug(category: "input", "momentumCommand \(command.logSummary)")
            performer.perform(command)
        }

        guard !command.isMomentumEnd,
              isCurrentMomentumGeneration(generation) else {
            return
        }

        scheduleNextMomentumFrame(generation: generation, delayNanos: scrollMomentumSynthesizer.frameIntervalNanos)
    }

    private func momentumStartGuardNanos(frameIntervalNanos: UInt64) -> UInt64 {
        min(max(frameIntervalNanos * 2, minimumMomentumStartGuardNanos), maximumMomentumStartGuardNanos)
    }

    private func nextMomentumGeneration() -> UInt64 {
        momentumGenerationLock.withLock {
            momentumGeneration &+= 1
            return momentumGeneration
        }
    }

    private func isCurrentMomentumGeneration(_ generation: UInt64) -> Bool {
        momentumGenerationLock.withLock {
            momentumGeneration == generation
        }
    }
}

private extension InputEvent {
    var logSummary: String {
        switch kind {
        case .pointerMove(let move):
            return "kind=pointerMove dx=\(move.dx) dy=\(move.dy)"
        case .pointerButton(let button):
            return "kind=pointerButton button=\(button.button.rawValue) phase=\(button.phase.rawValue)"
        case .tap(let tap):
            return "kind=tap button=\(tap.button.rawValue) clickCount=\(tap.clickCount)"
        case .scroll(let scroll):
            return "kind=scroll dx=\(scroll.dx) dy=\(scroll.dy) phase=\(scroll.phase.rawValue) momentum=\(scroll.momentumPhase?.rawValue ?? "none")"
        case .magnify(let magnify):
            return "kind=magnify magnification=\(magnify.magnification) phase=\(magnify.phase.rawValue)"
        case .systemAction(let systemAction):
            return "kind=systemAction action=\(systemAction.action.rawValue)"
        case .contact(let contact):
            return "kind=contact phase=\(contact.phase.rawValue) count=\(contact.contactCount)"
        }
    }
}

private extension MacInputCommand {
    var isMomentumEnd: Bool {
        if case .scroll(0, 0, .ended, .ended) = self {
            return true
        }

        return false
    }

    var logSummary: String {
        switch self {
        case .move(let dx, let dy):
            return "move dx=\(dx) dy=\(dy)"
        case .drag(let button, let dx, let dy):
            return "drag button=\(button.rawValue) dx=\(dx) dy=\(dy)"
        case .button(let button, let phase, let clickCount):
            return "button button=\(button.rawValue) phase=\(phase.rawValue) clickCount=\(clickCount)"
        case .scroll(let dx, let dy, let phase, let momentumPhase):
            return "scroll dx=\(dx) dy=\(dy) phase=\(phase.rawValue) momentum=\(momentumPhase?.rawValue ?? "none")"
        case .magnify(let magnification, let phase):
            return "magnify magnification=\(magnification) phase=\(phase.rawValue)"
        case .systemAction(let action):
            return "systemAction action=\(action.rawValue)"
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
