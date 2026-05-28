import Foundation
import TrackpadKit
import TrackpadHostCore

@MainActor
final class HostAppModel: ObservableObject {
    @Published private(set) var isTrusted = AccessibilityPermission.isTrusted
    @Published private(set) var hasAutomationPermission = false
    @Published private(set) var status = HostRuntimeStatus.stopped
    @Published private(set) var pairingCode = PairingCode.generate()
    @Published private(set) var pairingQRCodePayload: HostPairingQRCodePayload?
    @Published private(set) var clientLogRequestStatus: String?
    @Published var pointerSpeedMultiplier = TrackpadConfiguration.defaults.pointer.speedMultiplier
    @Published var tapMaximumDurationMilliseconds = TrackpadConfiguration.defaults.gestures.tapMaximumDurationMilliseconds
    @Published var tapDragMaximumIntervalMilliseconds = TrackpadConfiguration.defaults.gestures.tapDragMaximumIntervalMilliseconds
    @Published var scrollReleaseTapSuppressionMilliseconds = TrackpadConfiguration.defaults.gestures.scrollReleaseTapSuppressionMilliseconds
    @Published var scrollMomentumAmount = TrackpadConfiguration.defaults.scrollMomentum.amount
    @Published var scrollMomentumDecayRate = TrackpadConfiguration.defaults.scrollMomentum.decayRate
    @Published var scrollMomentumTailWindowMilliseconds = TrackpadConfiguration.defaults.scrollMomentum.tailWindowMilliseconds

    private var server: LanHostServer?
    private let logger = FileHostLogger()
    private var configurationSyncState = ConfigurationSyncState(configuration: .defaults)
    private var isApplyingRemoteConfiguration = false

    var logFilePath: String {
        logger.fileURL.path
    }

    init() {
        logger.info(category: "app", "host app model initialized logPath=\(logger.fileURL.path)")
        refreshPairingQRCodePayload()
    }

    func requestPermission() {
        AccessibilityPermission.requestIfNeeded()
        refreshPermission()
    }

    func requestAutomationPermission() {
        hasAutomationPermission = AutomationPermission.requestSystemEventsAccess(logger: logger)
    }

    func refreshPermission() {
        isTrusted = AccessibilityPermission.isTrusted
        hasAutomationPermission = AutomationPermission.checkSystemEventsAccess(logger: logger)
        refreshPairingQRCodePayload()
    }

    func startServer() {
        guard server == nil else {
            return
        }

        logger.info(category: "app", "starting host app server logPath=\(logger.fileURL.path)")
        refreshPairingQRCodePayload()
        let configuration = currentConfiguration
        _ = configurationSyncState.applyLocal(
            configuration,
            sourceDeviceId: "macos-host",
            updatedAtNanos: DispatchTime.now().uptimeNanoseconds
        )
        let processor = HostEventProcessor(
            configuration: configuration,
            performer: MacInputInjector(logger: logger),
            logger: logger
        )
        let server = LanHostServer(
            pairingPolicy: PairingPolicy(requiredCode: pairingCode),
            processor: processor,
            initialConfiguration: configuration,
            logger: logger
        ) { [weak self] status in
            Task { @MainActor in
                self?.status = status
            }
        } configurationHandler: { [weak self] configuration in
            Task { @MainActor in
                self?.applyRemoteConfiguration(configuration)
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
        refreshPairingQRCodePayload()
    }

    func requestClientLogs() {
        guard let server else {
            clientLogRequestStatus = "Server is not running"
            return
        }

        server.requestClientLogUpload()
        clientLogRequestStatus = "Requested client logs"
    }

    func syncConfigurationFromControls() {
        guard !isApplyingRemoteConfiguration else {
            return
        }

        let configuration = currentConfiguration
        guard configurationSyncState.applyLocal(
            configuration,
            sourceDeviceId: "macos-host",
            updatedAtNanos: DispatchTime.now().uptimeNanoseconds
        ) != nil else {
            return
        }

        server?.updateLocalConfiguration(configuration)
        logger.info(category: "config", "host local configuration changed pointer=\(configuration.pointer.speedMultiplier) momentum=\(configuration.scrollMomentum.amount)")
    }

    private func refreshPairingQRCodePayload() {
        pairingQRCodePayload = HostPairingQRCodePayloadFactory.make(pairingCode: pairingCode)
    }

    private var currentConfiguration: TrackpadConfiguration {
        TrackpadConfiguration(
            pointer: PointerConfiguration(speedMultiplier: pointerSpeedMultiplier),
            gestures: GestureConfiguration(
                tapMaximumDurationMilliseconds: tapMaximumDurationMilliseconds,
                tapDragMaximumIntervalMilliseconds: tapDragMaximumIntervalMilliseconds,
                scrollReleaseTapSuppressionMilliseconds: scrollReleaseTapSuppressionMilliseconds
            ),
            scrollMomentum: ScrollMomentumSettings(
                amount: scrollMomentumAmount,
                decayRate: scrollMomentumDecayRate,
                tailWindowMilliseconds: scrollMomentumTailWindowMilliseconds
            )
        )
    }

    private func applyRemoteConfiguration(_ configuration: TrackpadConfiguration) {
        guard configurationSyncState.applyRemote(
            ConfigurationSyncSnapshot(
                revision: configurationSyncState.revision,
                updatedAtNanos: DispatchTime.now().uptimeNanoseconds,
                sourceDeviceId: "remote",
                configuration: configuration
            )
        ) == .applied else {
            return
        }

        isApplyingRemoteConfiguration = true
        pointerSpeedMultiplier = configuration.pointer.speedMultiplier
        tapMaximumDurationMilliseconds = configuration.gestures.tapMaximumDurationMilliseconds
        tapDragMaximumIntervalMilliseconds = configuration.gestures.tapDragMaximumIntervalMilliseconds
        scrollReleaseTapSuppressionMilliseconds = configuration.gestures.scrollReleaseTapSuppressionMilliseconds
        scrollMomentumAmount = configuration.scrollMomentum.amount
        scrollMomentumDecayRate = configuration.scrollMomentum.decayRate
        scrollMomentumTailWindowMilliseconds = configuration.scrollMomentum.tailWindowMilliseconds
        isApplyingRemoteConfiguration = false
    }
}
