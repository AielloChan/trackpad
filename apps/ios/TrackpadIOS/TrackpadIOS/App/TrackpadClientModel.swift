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
    @Published var pointerSpeedMultiplier = 2.1
    @Published var tapMaximumDurationMilliseconds = 250.0
    @Published var tapDragMaximumIntervalMilliseconds = 140.0
    @Published var scrollReleaseTapSuppressionMilliseconds = 80.0

    private let client = TrackpadHostClient()
    private let diagnosticLogStore = ClientDiagnosticLogStore()
    private let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "ios-device"
    private let deviceName = UIDevice.current.name
    private var mapper = TouchSurfaceEventMapper()
    private var selectedDiscoveredHost: DiscoveredTrackpadHost?
    private var isDiscoveryRunning = false
    private var didRunDebugAutomation = false
    private var latencyTask: Task<Void, Never>?
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
        client.pathUpdateHandler = { [weak self] snapshot in
            Task { @MainActor [weak self] in
                self?.connectionPathLabel = snapshot.shortLabel
            }
        }
        client.connectionAttemptHandler = { [weak self] diagnostic in
            Task { @MainActor [weak self] in
                self?.recordDiagnosticLog("######### ios.transport \(diagnostic.message)")
            }
        }
        client.inputReportDiagnosticHandler = { [weak self] message in
            Task { @MainActor [weak self] in
                self?.recordDiagnosticLog("######### ios.report \(message)")
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

    func startDiscovery() {
        guard !isDiscoveryRunning else {
            return
        }

        isDiscoveryRunning = true
        hostBrowser.start()
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
        guard connectionState != .connecting else {
            return
        }

        connectionState = .connecting
        let configuration: TrackpadConnectionConfiguration

        if let selectedDiscoveredHost, host == selectedDiscoveredHost.name, port == "Bonjour" {
            configuration = TrackpadConnectionConfiguration(
                address: selectedDiscoveredHost.address,
                pairingCode: pairingCode,
                deviceId: deviceId,
                deviceName: deviceName
            )
        } else {
            guard let portValue = UInt16(port) else {
                connectionState = .failed("Invalid port")
                return
            }

            configuration = TrackpadConnectionConfiguration(
                host: host,
                port: portValue,
                pairingCode: pairingCode,
                deviceId: deviceId,
                deviceName: deviceName
            )
        }

        Task {
            do {
                try await client.connect(configuration: configuration)
                connectionState = .connected
                startLatencyUpdates()
                if sendSampleMoveAfterConnect {
                    try await sendDebugSampleMove()
                }
            } catch {
                stopLatencyUpdates()
                connectionState = .failed(String(describing: error))
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
            connect()
        } catch {
            connectionState = .failed("Invalid pairing QR code")
        }
    }

    func disconnect() {
        stopLatencyUpdates()
        client.disconnect()
        mapper.end()
        connectionPathLabel = "Path --"
        connectionState = .disconnected
    }

    func touchBegan(with contacts: [TouchContact]) {
        guard isConnected else {
            return
        }

        applyGestureConfiguration()
        if contacts.count >= 2 {
            logScrollTouchDiagnostic("begin contacts=\(contacts.scrollDiagnosticSummary)")
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
        logScrollEvents("move contacts=\(contacts.scrollDiagnosticSummary)", events: events)
        send(events)
    }

    func touchEnded(with contacts: [TouchContact]) {
        applyGestureConfiguration()
        guard isConnected else {
            mapper.end()
            return
        }

        let events = mapper.end(with: contacts)
        logScrollEvents("end contacts=\(contacts.scrollDiagnosticSummary)", events: events)
        send(events)
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
        guard let selectedDiscoveredHost else {
            return
        }

        if hosts.contains(selectedDiscoveredHost) {
            return
        }

        self.selectedDiscoveredHost = nil
        selectedHostID = nil
        if port == "Bonjour" {
            port = "44787"
        }
    }

    private func applyGestureConfiguration() {
        mapper.gestureConfiguration = TouchGestureConfiguration(
            tapMaximumDurationMilliseconds: tapMaximumDurationMilliseconds,
            tapDragMaximumIntervalMilliseconds: tapDragMaximumIntervalMilliseconds,
            scrollReleaseTapSuppressionMilliseconds: scrollReleaseTapSuppressionMilliseconds
        )
    }

    private func send(_ events: [InputEvent]) {
        guard !events.isEmpty else {
            return
        }

        let tunedEvents = InputEventTuning(pointerSpeedMultiplier: pointerSpeedMultiplier).apply(to: events)
        sentEventCounter += tunedEvents.count
        do {
            try client.enqueue(tunedEvents)
        } catch {
            handleInputSendFailure(String(describing: error))
        }
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
        connectionState = .failed(message)
        client.disconnect()
    }

    func recordDiagnosticLog(_ message: String) {
        print(message)
        diagnosticLogStore.append(message)
    }

    private func logScrollTouchDiagnostic(_ message: String) {
        recordDiagnosticLog("######### ios.scroll \(message)")
    }

    private func logScrollEvents(_ prefix: String, events: [InputEvent]) {
        guard events.containsScrollEvent else {
            return
        }

        logScrollDiagnostic("\(prefix) events=\(events.scrollDiagnosticSummary)")
    }

    private func logScrollDiagnostic(_ message: String) {
        recordDiagnosticLog("######### ios.scroll \(message)")
    }

    private func formatScroll(_ value: Double) -> String {
        String(format: "%.3f", value)
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

    var scrollDiagnosticSummary: String {
        map { event in
            switch event.kind {
            case .pointerMove:
                return "seq=\(event.sequenceNumber):pointer"
            case .pointerButton(let button):
                return "seq=\(event.sequenceNumber):button(\(button.button.rawValue),\(button.phase.rawValue))"
            case .tap(let tap):
                return "seq=\(event.sequenceNumber):tap(\(tap.button.rawValue))"
            case .scroll(let scroll):
                return "seq=\(event.sequenceNumber):scroll(dx=\(String(format: "%.3f", scroll.dx)),dy=\(String(format: "%.3f", scroll.dy)),phase=\(scroll.phase.rawValue),momentum=\(scroll.momentumPhase?.rawValue ?? "none"))"
            case .systemAction(let systemAction):
                return "seq=\(event.sequenceNumber):systemAction(\(systemAction.action.rawValue))"
            }
        }
        .joined(separator: "|")
    }
}
