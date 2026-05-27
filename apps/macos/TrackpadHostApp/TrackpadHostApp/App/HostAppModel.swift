import Foundation
import TrackpadHostCore

@MainActor
final class HostAppModel: ObservableObject {
    @Published private(set) var isTrusted = AccessibilityPermission.isTrusted
    @Published private(set) var status = HostRuntimeStatus.stopped
    @Published private(set) var pairingCode = PairingCode.generate()

    private var server: LanHostServer?
    private let logger = FileHostLogger()

    var logFilePath: String {
        logger.fileURL.path
    }

    init() {
        logger.info(category: "app", "host app model initialized logPath=\(logger.fileURL.path)")
    }

    func requestPermission() {
        AccessibilityPermission.requestIfNeeded()
        refreshPermission()
    }

    func refreshPermission() {
        isTrusted = AccessibilityPermission.isTrusted
    }

    func startServer() {
        guard server == nil else {
            return
        }

        logger.info(category: "app", "starting host app server logPath=\(logger.fileURL.path)")
        let processor = HostEventProcessor(performer: MacInputInjector(), logger: logger)
        let server = LanHostServer(
            pairingPolicy: PairingPolicy(requiredCode: pairingCode),
            processor: processor,
            logger: logger
        ) { [weak self] status in
            Task { @MainActor in
                self?.status = status
            }
        }

        do {
            try server.start()
            self.server = server
        } catch {
            logger.error(category: "app", "server start failed error=\(String(describing: error))")
            status = HostRuntimeStatus(
                state: .failed,
                port: HostDefaults.tcpPort,
                lastError: String(describing: error)
            )
        }
    }

    func stopServer() {
        logger.info(category: "app", "stopping host app server")
        server?.stop()
        server = nil
        status = .stopped
    }

    func regeneratePairingCode() {
        guard server == nil else {
            return
        }

        pairingCode = PairingCode.generate()
    }
}
