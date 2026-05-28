import TrackpadKit

public final class HostEventProcessor {
    private var mapper: MacInputMapper
    private let performer: MacInputPerforming
    private let logger: any HostLogging

    public private(set) var handledEventCount = 0

    public init(
        mapper: MacInputMapper = MacInputMapper(),
        performer: MacInputPerforming,
        logger: any HostLogging = DisabledHostLogger()
    ) {
        self.mapper = mapper
        self.performer = performer
        self.logger = logger
    }

    public func handle(_ event: InputEvent) {
        logger.debug(category: "input", "input sequence=\(event.sequenceNumber) \(event.logSummary)")
        if event.isScroll {
            logger.info(category: "input", "######### host.scroll input handledNext=\(handledEventCount + 1) sequence=\(event.sequenceNumber) timestamp=\(event.timestampNanos) \(event.logSummary)")
        }
        let commands = mapper.commands(for: event)
        for command in commands {
            logger.debug(category: "input", "command \(command.logSummary)")
            if command.isScroll {
                logger.info(category: "input", "######### host.scroll command sequence=\(event.sequenceNumber) \(command.logSummary)")
            }
            performer.perform(command)
        }
        handledEventCount += 1
    }
}

private extension InputEvent {
    var isScroll: Bool {
        if case .scroll = kind {
            return true
        }

        return false
    }

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
        }
    }
}

private extension MacInputCommand {
    var isScroll: Bool {
        if case .scroll = self {
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
        case .systemAction(let action):
            return "systemAction action=\(action.rawValue)"
        }
    }
}
