import Foundation
import TrackpadKit

public final class HostEventProcessor: @unchecked Sendable {
    private var mapper: MacInputMapper
    private var scrollMomentumSynthesizer: MacScrollMomentumSynthesizer
    private let performer: MacInputPerforming
    private let logger: any HostLogging
    private let momentumQueue = DispatchQueue(label: "trackpad.host.scroll-momentum", qos: .userInteractive)
    private var momentumGeneration: UInt64 = 0

    public private(set) var configuration: TrackpadConfiguration
    public private(set) var handledEventCount = 0

    public init(
        mapper: MacInputMapper = MacInputMapper(),
        scrollMomentumSynthesizer: MacScrollMomentumSynthesizer = MacScrollMomentumSynthesizer(),
        configuration: TrackpadConfiguration = .defaults,
        performer: MacInputPerforming,
        logger: any HostLogging = DisabledHostLogger()
    ) {
        self.mapper = mapper
        self.scrollMomentumSynthesizer = scrollMomentumSynthesizer
        self.configuration = configuration
        self.performer = performer
        self.logger = logger
        self.scrollMomentumSynthesizer.updateSettings(configuration.scrollMomentum)
    }

    public func applyConfiguration(_ configuration: TrackpadConfiguration) {
        self.configuration = configuration
        scrollMomentumSynthesizer.updateSettings(configuration.scrollMomentum)
        logger.info(category: "config", "applied pointer=\(configuration.pointer.speedMultiplier) momentum=\(configuration.scrollMomentum.amount) decay=\(configuration.scrollMomentum.decayRate) tailMs=\(configuration.scrollMomentum.tailWindowMilliseconds)")
    }

    public func updateScrollMomentumSettings(_ settings: ScrollMomentumSettings) {
        applyConfiguration(configuration.withScrollMomentum(settings))
    }

    public func handle(_ event: InputEvent) {
        logger.debug(category: "input", "input sequence=\(event.sequenceNumber) \(event.logSummary)")
        if shouldCancelScheduledMomentum(for: event) {
            cancelScheduledMomentum()
        }

        let commands = mapper.commands(for: event)
        for command in commands {
            logger.debug(category: "input", "command \(command.logSummary)")
            performer.perform(command)
        }

        let momentumCommands = scrollMomentumSynthesizer.commands(after: event)
        scheduleMomentum(momentumCommands)
        handledEventCount += 1
    }

    private func shouldCancelScheduledMomentum(for event: InputEvent) -> Bool {
        switch event.kind {
        case .scroll(let scroll):
            return scroll.momentumPhase == nil
        case .pointerMove, .pointerButton, .tap, .systemAction, .contact:
            return true
        }
    }

    private func cancelScheduledMomentum() {
        momentumQueue.async {
            self.momentumGeneration &+= 1
        }
    }

    private func scheduleMomentum(_ commands: [MacInputCommand]) {
        guard !commands.isEmpty else {
            return
        }

        let frameIntervalNanos = scrollMomentumSynthesizer.frameIntervalNanos
        momentumQueue.async {
            self.momentumGeneration &+= 1
            let generation = self.momentumGeneration

            for (index, command) in commands.enumerated() {
                let delayNanos = min(UInt64(index + 1) * frameIntervalNanos, UInt64(Int.max))
                self.momentumQueue.asyncAfter(deadline: .now() + .nanoseconds(Int(delayNanos))) {
                    guard self.momentumGeneration == generation else {
                        return
                    }

                    self.logger.debug(category: "input", "momentumCommand \(command.logSummary)")
                    self.performer.perform(command)
                }
            }
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
            return "kind=tap button=\(tap.button.rawValue)"
        case .scroll(let scroll):
            return "kind=scroll dx=\(scroll.dx) dy=\(scroll.dy) phase=\(scroll.phase.rawValue) momentum=\(scroll.momentumPhase?.rawValue ?? "none")"
        case .systemAction(let systemAction):
            return "kind=systemAction action=\(systemAction.action.rawValue)"
        case .contact(let contact):
            return "kind=contact phase=\(contact.phase.rawValue) count=\(contact.contactCount)"
        }
    }
}

private extension MacInputCommand {
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
        case .systemAction(let action):
            return "systemAction action=\(action.rawValue)"
        }
    }
}
