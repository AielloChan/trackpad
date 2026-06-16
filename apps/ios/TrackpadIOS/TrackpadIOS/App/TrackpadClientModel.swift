import Foundation
import SwiftUI
import UIKit

@MainActor
final class TrackpadClientModel: ObservableObject {
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case failed(String)
    }

    @Published var host = "127.0.0.1"
    @Published var port = "44787"
    @Published var pairingCode = "123456"
    @Published private(set) var discoveredHosts: [DiscoveredTrackpadHost] = []
    @Published private(set) var selectedHostID: String?
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var latencyMilliseconds: Int?
    @Published private(set) var touchSampleRateHz: Int?
    @Published private(set) var sentEventRateHz: Int?
    @Published private(set) var connectionPathLabel = "Path --"
    @Published private(set) var pointerSpeedMultiplier = TrackpadConfiguration.defaults.pointer.speedMultiplier
    @Published private(set) var pointerAccelerationMaximumMultiplier = TrackpadConfiguration.defaults.pointer.accelerationMaximumMultiplier
    @Published private(set) var pointerAccelerationStartVelocity = TrackpadConfiguration.defaults.pointer.accelerationStartVelocity
    @Published private(set) var pointerAccelerationEndVelocity = TrackpadConfiguration.defaults.pointer.accelerationEndVelocity
    @Published private(set) var tapMaximumDurationMilliseconds = TrackpadConfiguration.defaults.gestures.tapMaximumDurationMilliseconds
    @Published private(set) var tapDragMaximumIntervalMilliseconds = TrackpadConfiguration.defaults.gestures.tapDragMaximumIntervalMilliseconds
    @Published private(set) var scrollReleaseTapSuppressionMilliseconds = TrackpadConfiguration.defaults.gestures.scrollReleaseTapSuppressionMilliseconds
    @Published private(set) var isScrollMomentumEnabled = TrackpadConfiguration.defaults.scrollMomentum.isEnabled
    @Published private(set) var scrollMomentumAmount = TrackpadConfiguration.defaults.scrollMomentum.amount
    @Published private(set) var scrollMomentumDecayRate = TrackpadConfiguration.defaults.scrollMomentum.decayRate
    @Published private(set) var scrollMomentumTailWindowMilliseconds = TrackpadConfiguration.defaults.scrollMomentum.tailWindowMilliseconds

    private let client = TrackpadHostClient()
    private let diagnosticLogStore = ClientDiagnosticLogStore()
    private let trustedHostStore = TrustedHostStore()
    private let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "ios-device"
    private let deviceName = UIDevice.current.name
    private var mapper = TouchSurfaceEventMapper()
    private var inputEventTuningState = InputEventTuningState()
    private var configurationSyncState = ConfigurationSyncState(configuration: .defaults)
    private var activeConnectionConfiguration: TrackpadConnectionConfiguration?
    private var selectedDiscoveredHost: DiscoveredTrackpadHost?
    private var pendingTrustedHostAliases: [String] = []
    private var automaticConnectAttemptCount = 0
    private var automaticConnectCandidateID: String?
    private var automaticConnectRetryTask: Task<Void, Never>?
    private var isAutomaticConnectSuppressed = false
    private var isDiscoveryRunning = false
    private var didRunDebugAutomation = false
    private var latencyTask: Task<Void, Never>?
    private var pendingTapFlushTask: Task<Void, Never>?
    private var touchMoveSampleCounter = 0
    private var sentEventCounter = 0
    private var lastRateSampleNanos = DispatchTime.now().uptimeNanoseconds
    private lazy var hostBrowser = BonjourTrackpadHostBrowser { [weak self] hosts in
        Task { @MainActor [weak self] in
            self?.applyDiscoveredHosts(hosts)
        }
    }

    init() {
        client.inputSendFailureHandler = { [weak self] message in
            Task { @MainActor [weak self] in
                self?.handleInputSendFailure(message)
            }
        }
        client.connectionClosedHandler = { [weak self] message in
            Task { @MainActor [weak self] in
                self?.handleConnectionClosed(message)
            }
        }
        client.pathUpdateHandler = { [weak self] snapshot in
            Task { @MainActor [weak self] in
                self?.connectionPathLabel = snapshot.shortLabel
            }
        }
        client.connectionAttemptHandler = { [weak self] diagnostic in
            Task { @MainActor [weak self] in
                self?.recordDiagnosticLog("ios.transport \(diagnostic.message)")
            }
        }
        client.inputReportDiagnosticHandler = { [weak self] message in
            Task { @MainActor [weak self] in
                self?.recordDiagnosticLog("ios.report \(message)")
            }
        }
        client.configurationSyncHandler = { [weak self] snapshot in
            Task { @MainActor [weak self] in
                self?.applyRemoteConfiguration(snapshot)
            }
        }
        client.trustedClientKeyHandler = { [weak self] key in
            Task { @MainActor [weak self] in
                self?.saveTrustedClientKey(key)
            }
        }
        client.logUploadProvider = { [diagnosticLogStore, deviceId, deviceName] request in
            try? diagnosticLogStore.makeUpload(
                requestId: request.id,
                deviceId: deviceId,
                deviceName: deviceName,
                createdAtNanos: DispatchTime.now().uptimeNanoseconds
            )
        }
    }

    var isConnected: Bool {
        connectionState == .connected
    }

    private enum ConnectionInitiator {
        case manual
        case automatic
    }

    func startDiscovery() {
        guard !isDiscoveryRunning else {
            attemptAutomaticTrustedConnectionIfNeeded()
            return
        }

        isDiscoveryRunning = true
        hostBrowser.start()
        attemptAutomaticTrustedConnectionIfNeeded()
    }

    func stopDiscovery() {
        guard isDiscoveryRunning else {
            return
        }

        isDiscoveryRunning = false
        hostBrowser.stop()
    }

    func select(_ discoveredHost: DiscoveredTrackpadHost) {
        selectedDiscoveredHost = discoveredHost
        selectedHostID = discoveredHost.id
        host = discoveredHost.name
        port = "Bonjour"
    }

    func connect(sendSampleMoveAfterConnect: Bool = false) {
        connect(sendSampleMoveAfterConnect: sendSampleMoveAfterConnect, initiator: .manual)
    }

    private func connect(
        sendSampleMoveAfterConnect: Bool = false,
        initiator: ConnectionInitiator
    ) {
        guard connectionState != .connecting else {
            return
        }

        if initiator == .manual {
            resetAutomaticConnectState()
            isAutomaticConnectSuppressed = false
        }

        connectionState = .connecting
        let configuration: TrackpadConnectionConfiguration

        if let selectedDiscoveredHost, host == selectedDiscoveredHost.name, port == "Bonjour" {
            let baseConfiguration = TrackpadConnectionConfiguration(
                address: selectedDiscoveredHost.address,
                pairingCode: pairingCode,
                deviceId: deviceId,
                deviceName: deviceName
            )
            configuration = configurationWithTrustedKey(baseConfiguration)
        } else {
            guard let portValue = UInt16(port) else {
                connectionState = .failed("Invalid port")
                return
            }

            let baseConfiguration = TrackpadConnectionConfiguration(
                host: host,
                port: portValue,
                pairingCode: pairingCode,
                deviceId: deviceId,
                deviceName: deviceName,
                trustedHostAliases: pendingTrustedHostAliases
            )
            configuration = configurationWithTrustedKey(baseConfiguration)
        }
        pendingTrustedHostAliases = []

        Task {
            do {
                activeConnectionConfiguration = configuration
                try await client.connect(configuration: configuration)
                connectionState = .connected
                if initiator == .automatic {
                    recordDiagnosticLog("ios.autoconnect transportConnected host=\(configuration.trustedHostIdentity)")
                }
                startLatencyUpdates()
                if sendSampleMoveAfterConnect {
                    try await sendDebugSampleMove()
                }
            } catch {
                activeConnectionConfiguration = nil
                stopLatencyUpdates()
                let message = String(describing: error)
                if initiator == .automatic {
                    handleAutomaticConnectFailure(message)
                } else {
                    connectionState = .failed(message)
                }
            }
        }
    }

    func connect(usingQRCodeMessage message: String) {
        do {
            let payload = try PairingQRCodePayload(urlString: message)
            guard payload.transport == PairingQRCodePayload.lanTCPTransport else {
                connectionState = .failed("Unsupported QR transport")
                return
            }

            selectedDiscoveredHost = nil
            selectedHostID = nil
            host = payload.host
            port = String(payload.port)
            pairingCode = payload.pairingCode
            pendingTrustedHostAliases = ["bonjour:\(payload.serviceName)"]
            connect()
        } catch {
            connectionState = .failed("Invalid pairing QR code")
        }
    }

    func disconnect() {
        disconnect(suppressAutomaticReconnect: true)
    }

    func disconnectForLifecycle() {
        disconnect(suppressAutomaticReconnect: false)
    }

    private func disconnect(suppressAutomaticReconnect: Bool) {
        if suppressAutomaticReconnect {
            isAutomaticConnectSuppressed = true
        }
        automaticConnectRetryTask?.cancel()
        automaticConnectRetryTask = nil
        stopLatencyUpdates()
        cancelPendingTapFlush()
        client.disconnect()
        activeConnectionConfiguration = nil
        mapper.cancelPendingEvents()
        mapper.end()
        inputEventTuningState = InputEventTuningState()
        connectionPathLabel = "Path --"
        connectionState = .disconnected
        recordDiagnosticLog("ios.autoconnect disconnected manual=\(suppressAutomaticReconnect)")
    }

    func touchBegan(with contacts: [TouchContact]) {
        guard isConnected else {
            return
        }

        cancelPendingTapFlush()
        applyGestureConfiguration()
        if contacts.count >= 2 {
            logScrollTouchDiagnostic("begin contacts=\(contacts.scrollDiagnosticSummary)")
        }
        if contacts.count == 3 {
            logSystemGestureDiagnostic("begin contacts=\(contacts.scrollDiagnosticSummary)")
        }
        if let contactEvent = mapper.contactBegan(with: contacts) {
            send([contactEvent])
        }
        send(mapper.begin(with: contacts))
    }

    func touchMoved(with contacts: [TouchContact]) {
        guard isConnected else {
            return
        }

        applyGestureConfiguration()
        touchMoveSampleCounter += 1
        let events = mapper.move(with: contacts)
        logDragDiagnostic("mapper.move contacts=\(contacts.scrollDiagnosticSummary) raw=\(events.eventDiagnosticSummary)", events: events)
        if contacts.count == 3 {
            logSystemGestureDiagnostic("move contacts=\(contacts.scrollDiagnosticSummary) events=\(events.eventDiagnosticSummary)")
        }
        logScrollEvents("move contacts=\(contacts.scrollDiagnosticSummary)", events: events)
        send(events)
    }

    func touchEnded(with contacts: [TouchContact]) {
        applyGestureConfiguration()
        guard isConnected else {
            cancelPendingTapFlush()
            mapper.cancelPendingEvents()
            mapper.end()
            return
        }

        let events = mapper.end(with: contacts)
        if contacts.count < 3 && events.containsSystemActionEvent {
            logSystemGestureDiagnostic("end contacts=\(contacts.scrollDiagnosticSummary) events=\(events.eventDiagnosticSummary)")
        }
        logScrollEvents("end contacts=\(contacts.scrollDiagnosticSummary)", events: events)
        send(events)
        schedulePendingTapFlush()
    }

    private func applyRemoteConfiguration(_ snapshot: ConfigurationSyncSnapshot) {
        guard configurationSyncState.applyRemote(snapshot) == .applied else {
            return
        }

        applyConfigurationToControls(snapshot.configuration)
        automaticConnectAttemptCount = 0
        automaticConnectCandidateID = nil
        recordDiagnosticLog("ios.configApplied source=\(snapshot.sourceDeviceId) revision=\(snapshot.revision)")
    }

    private func configurationWithTrustedKey(_ configuration: TrackpadConnectionConfiguration) -> TrackpadConnectionConfiguration {
        let trustedClientKey: String?
        do {
            trustedClientKey = try trustedHostStore.clientKey(
                for: configuration,
                timestampNanos: DispatchTime.now().uptimeNanoseconds
            )
        } catch {
            trustedClientKey = nil
            recordDiagnosticLog("ios.trust loadFailed host=\(configuration.trustedHostIdentity) error=\(String(describing: error))")
        }
        recordDiagnosticLog("ios.trust lookup host=\(configuration.trustedHostIdentity) found=\(trustedClientKey != nil) aliases=\(configuration.trustedHostAliases.joined(separator: ","))")

        switch configuration.address {
        case .manual:
            return TrackpadConnectionConfiguration(
                host: configuration.host,
                port: configuration.port,
                pairingCode: configuration.pairingCode,
                deviceId: configuration.deviceId,
                deviceName: configuration.deviceName,
                trustedClientKey: trustedClientKey,
                trustedHostAliases: configuration.trustedHostAliases
            )
        case .bonjour:
            return TrackpadConnectionConfiguration(
                address: configuration.address,
                pairingCode: configuration.pairingCode,
                deviceId: configuration.deviceId,
                deviceName: configuration.deviceName,
                trustedClientKey: trustedClientKey,
                trustedHostAliases: configuration.trustedHostAliases
            )
        }
    }

    private func saveTrustedClientKey(_ key: TrustedClientKey) {
        guard let activeConnectionConfiguration else {
            return
        }

        do {
            try trustedHostStore.save(
                key,
                for: activeConnectionConfiguration,
                timestampNanos: DispatchTime.now().uptimeNanoseconds
            )
            recordDiagnosticLog("ios.trust saved host=\(activeConnectionConfiguration.trustedHostIdentity) deviceId=\(key.deviceId)")
        } catch {
            recordDiagnosticLog("ios.trust saveFailed host=\(activeConnectionConfiguration.trustedHostIdentity) error=\(String(describing: error))")
        }
    }

#if DEBUG
    func runDebugAutomationIfRequested() {
        guard !didRunDebugAutomation else {
            return
        }

        didRunDebugAutomation = true
        let environment = ProcessInfo.processInfo.environment
        let shouldUseDiscoveredHost = environment["TRACKPAD_AUTOCONNECT_DISCOVERED"] == "1"
        guard environment["TRACKPAD_AUTOCONNECT"] == "1" || shouldUseDiscoveredHost else {
            return
        }

        if shouldUseDiscoveredHost {
            connectToFirstDiscoveredHostWhenAvailable(
                sendSampleMoveAfterConnect: environment["TRACKPAD_SEND_SAMPLE_MOVE"] == "1"
            )
        } else {
            connect(sendSampleMoveAfterConnect: environment["TRACKPAD_SEND_SAMPLE_MOVE"] == "1")
        }
    }
#endif

    private func sendDebugSampleMove() async throws {
        applyGestureConfiguration()
        _ = mapper.begin(at: TouchPoint(x: 0, y: 0))
        guard let event = mapper.move(to: TouchPoint(x: 80, y: 0)) else {
            return
        }

        try await client.send(event)
    }

#if DEBUG
    private func connectToFirstDiscoveredHostWhenAvailable(sendSampleMoveAfterConnect: Bool) {
        Task {
            for _ in 0..<20 {
                if let discoveredHost = discoveredHosts.first {
                    select(discoveredHost)
                    connect(sendSampleMoveAfterConnect: sendSampleMoveAfterConnect)
                    return
                }

                try? await Task.sleep(nanoseconds: 250_000_000)
            }

            connectionState = .failed("No discovered host")
        }
    }
#endif

    private func applyDiscoveredHosts(_ hosts: [DiscoveredTrackpadHost]) {
        discoveredHosts = hosts

        if let selectedDiscoveredHost, !hosts.contains(selectedDiscoveredHost) {
            self.selectedDiscoveredHost = nil
            selectedHostID = nil
            if port == "Bonjour" {
                port = "44787"
            }
        }

        attemptAutomaticTrustedConnectionIfNeeded()
    }

    private func attemptAutomaticTrustedConnectionIfNeeded() {
        guard !isAutomaticConnectSuppressed,
              isConnectionIdleForAutomaticConnect,
              automaticConnectAttemptCount < 3,
              let candidate = trustedAutomaticConnectCandidate() else {
            return
        }

        if automaticConnectCandidateID != candidate.id {
            automaticConnectCandidateID = candidate.id
            automaticConnectAttemptCount = 0
        }

        guard automaticConnectAttemptCount < 3 else {
            return
        }

        automaticConnectRetryTask?.cancel()
        automaticConnectRetryTask = nil
        automaticConnectAttemptCount += 1
        select(candidate)
        recordDiagnosticLog("ios.autoconnect attempt=\(automaticConnectAttemptCount) host=\(candidate.name)")
        connect(initiator: .automatic)
    }

    private var isConnectionIdleForAutomaticConnect: Bool {
        switch connectionState {
        case .disconnected, .failed:
            return true
        case .connecting, .connected:
            return false
        }
    }

    private func trustedAutomaticConnectCandidate() -> DiscoveredTrackpadHost? {
        discoveredHosts.first { discoveredHost in
            let configuration = TrackpadConnectionConfiguration(
                address: discoveredHost.address,
                pairingCode: pairingCode,
                deviceId: deviceId,
                deviceName: deviceName
            )

            do {
                return try trustedHostStore.hasClientKey(for: configuration)
            } catch {
                recordDiagnosticLog("ios.autoconnect trustLookupFailed host=\(configuration.trustedHostIdentity) error=\(String(describing: error))")
                return false
            }
        }
    }

    private func handleAutomaticConnectFailure(_ message: String) {
        recordDiagnosticLog("ios.autoconnect failed attempt=\(automaticConnectAttemptCount) error=\(message)")
        guard automaticConnectAttemptCount < 3 else {
            isAutomaticConnectSuppressed = true
            connectionState = .failed("Auto connect failed")
            return
        }

        connectionState = .failed("Auto connect failed, retrying")
        automaticConnectRetryTask?.cancel()
        automaticConnectRetryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else {
                return
            }

            self?.attemptAutomaticTrustedConnectionIfNeeded()
        }
    }

    private func resetAutomaticConnectState() {
        automaticConnectRetryTask?.cancel()
        automaticConnectRetryTask = nil
        automaticConnectAttemptCount = 0
        automaticConnectCandidateID = nil
    }

    private func applyGestureConfiguration() {
        mapper.gestureConfiguration = TouchGestureConfiguration(
            tapMaximumDurationMilliseconds: tapMaximumDurationMilliseconds,
            tapDragMaximumIntervalMilliseconds: tapDragMaximumIntervalMilliseconds,
            scrollReleaseTapSuppressionMilliseconds: scrollReleaseTapSuppressionMilliseconds
        )
    }

    private func applyConfigurationToControls(_ configuration: TrackpadConfiguration) {
        pointerSpeedMultiplier = configuration.pointer.speedMultiplier
        pointerAccelerationMaximumMultiplier = configuration.pointer.accelerationMaximumMultiplier
        pointerAccelerationStartVelocity = configuration.pointer.accelerationStartVelocity
        pointerAccelerationEndVelocity = configuration.pointer.accelerationEndVelocity
        tapMaximumDurationMilliseconds = configuration.gestures.tapMaximumDurationMilliseconds
        tapDragMaximumIntervalMilliseconds = configuration.gestures.tapDragMaximumIntervalMilliseconds
        scrollReleaseTapSuppressionMilliseconds = configuration.gestures.scrollReleaseTapSuppressionMilliseconds
        isScrollMomentumEnabled = configuration.scrollMomentum.isEnabled
        scrollMomentumAmount = configuration.scrollMomentum.amount
        scrollMomentumDecayRate = configuration.scrollMomentum.decayRate
        scrollMomentumTailWindowMilliseconds = configuration.scrollMomentum.tailWindowMilliseconds
        applyGestureConfiguration()
    }

    private func send(_ events: [InputEvent]) {
        guard !events.isEmpty else {
            return
        }

        let pointerConfiguration = PointerConfiguration(
            speedMultiplier: pointerSpeedMultiplier,
            accelerationMaximumMultiplier: pointerAccelerationMaximumMultiplier,
            accelerationStartVelocity: pointerAccelerationStartVelocity,
            accelerationEndVelocity: pointerAccelerationEndVelocity
        )
        let tunedEvents = InputEventTuning(pointerConfiguration: pointerConfiguration).apply(to: events, state: &inputEventTuningState)
        if events.containsDragDiagnosticEvent || tunedEvents.containsDragDiagnosticEvent {
            logDragDiagnostic(
                "send pointerSpeed=\(String(format: "%.3f", pointerSpeedMultiplier)) raw=\(events.eventDiagnosticSummary) tuned=\(tunedEvents.eventDiagnosticSummary)",
                events: tunedEvents
            )
        }
        if tunedEvents.containsSystemActionEvent {
            logSystemGestureDiagnostic("send events=\(tunedEvents.eventDiagnosticSummary)")
        }
        sentEventCounter += tunedEvents.count
        do {
            try client.enqueue(tunedEvents)
        } catch {
            handleInputSendFailure(String(describing: error))
        }
    }

    private func schedulePendingTapFlush() {
        cancelPendingTapFlush()
        let delayNanos = UInt64((tapDragMaximumIntervalMilliseconds * 1_000_000).rounded())
        pendingTapFlushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delayNanos)
            guard !Task.isCancelled,
                  let self,
                  self.isConnected else {
                return
            }

            self.applyGestureConfiguration()
            self.send(self.mapper.flushExpiredPendingEvents())
        }
    }

    private func cancelPendingTapFlush() {
        pendingTapFlushTask?.cancel()
        pendingTapFlushTask = nil
    }

    private func startLatencyUpdates() {
        stopLatencyUpdates()
        latencyTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    let latencySeconds = try await self?.client.measureLatency()
                    guard !Task.isCancelled else {
                        return
                    }

                    if let latencySeconds {
                        self?.latencyMilliseconds = Int((latencySeconds * 1_000).rounded())
                    } else {
                        self?.latencyMilliseconds = nil
                    }
                } catch {
                    guard !Task.isCancelled else {
                        return
                    }

                    self?.latencyMilliseconds = nil
                }

                self?.updateInputRateStats()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func stopLatencyUpdates() {
        latencyTask?.cancel()
        latencyTask = nil
        latencyMilliseconds = nil
        touchSampleRateHz = nil
        sentEventRateHz = nil
        connectionPathLabel = "Path --"
        touchMoveSampleCounter = 0
        sentEventCounter = 0
        lastRateSampleNanos = DispatchTime.now().uptimeNanoseconds
    }

    private func updateInputRateStats() {
        let now = DispatchTime.now().uptimeNanoseconds
        let elapsedSeconds = Double(now - lastRateSampleNanos) / 1_000_000_000
        guard elapsedSeconds > 0 else {
            return
        }

        touchSampleRateHz = Int((Double(touchMoveSampleCounter) / elapsedSeconds).rounded())
        sentEventRateHz = Int((Double(sentEventCounter) / elapsedSeconds).rounded())
        touchMoveSampleCounter = 0
        sentEventCounter = 0
        lastRateSampleNanos = now
    }

    private func handleInputSendFailure(_ message: String) {
        stopLatencyUpdates()
        activeConnectionConfiguration = nil
        connectionState = .failed(message)
        client.disconnect()
        attemptAutomaticTrustedConnectionIfNeeded()
    }

    private func handleConnectionClosed(_ message: String) {
        guard connectionState == .connected || connectionState == .connecting else {
            return
        }

        stopLatencyUpdates()
        activeConnectionConfiguration = nil
        connectionState = .failed(message)
        recordDiagnosticLog("ios.connection closed message=\(message)")
        attemptAutomaticTrustedConnectionIfNeeded()
    }

    func recordDiagnosticLog(_ message: String) {
        print(message)
        diagnosticLogStore.append(message)
    }

    private func logScrollTouchDiagnostic(_ message: String) {
        recordDiagnosticLog("ios.scroll \(message)")
    }

    private func logScrollEvents(_ prefix: String, events: [InputEvent]) {
        guard events.containsScrollEvent else {
            return
        }

        logScrollDiagnostic("\(prefix) events=\(events.scrollDiagnosticSummary)")
    }

    private func logScrollDiagnostic(_ message: String) {
        recordDiagnosticLog("ios.scroll \(message)")
    }

    private func logSystemGestureDiagnostic(_ message: String) {
        recordDiagnosticLog("ios.systemGesture \(message)")
    }

    private func logDragDiagnostic(_ message: String, events: [InputEvent]) {
        guard events.containsDragDiagnosticEvent else {
            return
        }

        recordDiagnosticLog("######### ios.drag \(message)")
    }

}

private extension Array where Element == TouchContact {
    var scrollDiagnosticSummary: String {
        guard !isEmpty else {
            return "[]"
        }

        return map { contact in
            "id=\(contact.id) x=\(String(format: "%.3f", contact.point.x)) y=\(String(format: "%.3f", contact.point.y))"
        }
        .joined(separator: ";")
    }
}

private extension Array where Element == InputEvent {
    var containsScrollEvent: Bool {
        contains { event in
            if case .scroll = event.kind {
                return true
            }

            return false
        }
    }

    var containsSystemActionEvent: Bool {
        contains { event in
            if case .systemAction = event.kind {
                return true
            }

            return false
        }
    }

    var containsDragDiagnosticEvent: Bool {
        contains { event in
            switch event.kind {
            case .pointerMove, .pointerButton, .tap:
                return true
            case .scroll, .magnify, .systemAction, .contact:
                return false
            }
        }
    }

    var scrollDiagnosticSummary: String {
        eventDiagnosticSummary
    }

    var eventDiagnosticSummary: String {
        map { event in
            switch event.kind {
            case .pointerMove(let move):
                return "seq=\(event.sequenceNumber):pointer(dx=\(String(format: "%.3f", move.dx)),dy=\(String(format: "%.3f", move.dy)))"
            case .pointerButton(let button):
                return "seq=\(event.sequenceNumber):button(\(button.button.rawValue),\(button.phase.rawValue))"
            case .tap(let tap):
                return "seq=\(event.sequenceNumber):tap(\(tap.button.rawValue),clickCount=\(tap.clickCount))"
            case .scroll(let scroll):
                return "seq=\(event.sequenceNumber):scroll(dx=\(String(format: "%.3f", scroll.dx)),dy=\(String(format: "%.3f", scroll.dy)),phase=\(scroll.phase.rawValue),momentum=\(scroll.momentumPhase?.rawValue ?? "none"))"
            case .magnify(let magnify):
                return "seq=\(event.sequenceNumber):magnify(magnification=\(String(format: "%.3f", magnify.magnification)),phase=\(magnify.phase.rawValue))"
            case .systemAction(let systemAction):
                return "seq=\(event.sequenceNumber):systemAction(\(systemAction.action.rawValue))"
            case .contact(let contact):
                return "seq=\(event.sequenceNumber):contact(\(contact.phase.rawValue),\(contact.contactCount))"
            }
        }
        .joined(separator: "|")
    }
}
