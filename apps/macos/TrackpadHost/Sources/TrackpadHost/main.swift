import Dispatch
import Darwin
import Foundation
import TrackpadHostCore
import TrackpadKit

let arguments = Array(CommandLine.arguments.dropFirst())
let command = arguments.first
let defaultDevelopmentPairingCode = PairingCode("123456")
let logger = FileHostLogger()
let injector = MacInputInjector(diagnostics: { message in
    logger.info(category: "input", message)
})

func logLine(_ message: String) {
    print(message)
    fflush(stdout)
}

switch command {
case "status":
    logLine("Accessibility trusted: \(AccessibilityPermission.isTrusted)")
case "request-permission":
    AccessibilityPermission.requestIfNeeded()
    logLine("Accessibility trusted: \(AccessibilityPermission.isTrusted)")
case "log-path":
    logLine(logger.fileURL.path)
case "move-test":
    injector.perform(.move(dx: 100, dy: 0))
case "left-click-test":
    injector.perform(.button(button: .left, phase: .down, clickCount: 1))
    injector.perform(.button(button: .left, phase: .up, clickCount: 1))
case "right-click-test":
    injector.perform(.button(button: .right, phase: .down, clickCount: 1))
    injector.perform(.button(button: .right, phase: .up, clickCount: 1))
case "scroll-test":
    injector.perform(.scroll(dx: 0, dy: -200, phase: .changed, momentumPhase: nil))
case "serve":
    let pairingCode = arguments.dropFirst().first.map(PairingCode.init) ?? defaultDevelopmentPairingCode
    logger.info(category: "cli", "serve requested logPath=\(logger.fileURL.path)")
    let processor = HostEventProcessor(performer: injector, logger: logger)
    let server = LanHostServer(
        pairingPolicy: PairingPolicy(requiredCode: pairingCode),
        processor: processor,
        logger: logger
    ) { status in
        logLine("Host status: \(status.state.rawValue), port: \(status.port ?? 0), connections: \(status.connectionCount), authorized: \(status.authorizedConnectionCount), handled: \(status.handledEventCount)")
        if let lastError = status.lastError {
            logLine("Host error: \(lastError)")
        }
    }

    do {
        try server.start()
        logLine("TrackpadHost serving on TCP \(HostDefaults.tcpPort), Bonjour \(HostDefaults.bonjourType)")
        logLine("Pairing code: \(pairingCode.value)")
        dispatchMain()
    } catch {
        logLine("Failed to start TrackpadHost server: \(error)")
        Foundation.exit(1)
    }
case "send-sample-event":
    let pairingCode = arguments.dropFirst().first.map(PairingCode.init) ?? defaultDevelopmentPairingCode
    let event = InputEvent(
        sequenceNumber: UInt64(Date().timeIntervalSince1970 * 1_000),
        timestampNanos: UInt64(Date().timeIntervalSince1970 * 1_000_000_000),
        kind: .pointerMove(PointerMoveEvent(dx: 80, dy: 0))
    )

    do {
        try InputEventClient.send(event, pairingCode: pairingCode)
        logLine("Sent sample pointer move event to 127.0.0.1:\(HostDefaults.tcpPort)")
    } catch {
        logLine("Failed to send sample event: \(error)")
        Foundation.exit(1)
    }
default:
    logLine("Usage: TrackpadHost status|request-permission|log-path|move-test|left-click-test|right-click-test|scroll-test|serve [pairing-code]|send-sample-event [pairing-code]")
}
