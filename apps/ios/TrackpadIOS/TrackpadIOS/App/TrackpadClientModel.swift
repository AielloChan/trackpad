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
    @Published var pointerSpeedMultiplier = 2.1
    @Published var scrollMomentumAmount = 1.8
    @Published var tapMaximumDurationMilliseconds = 250.0
    @Published var tapDragMaximumIntervalMilliseconds = 140.0
    @Published var scrollReleaseTapSuppressionMilliseconds = 80.0

    private let client = TrackpadHostClient()
    private var mapper = TouchSurfaceEventMapper()
    private var selectedDiscoveredHost: DiscoveredTrackpadHost?
    private var isDiscoveryRunning = false
    private var didRunDebugAutomation = false
    private var latencyTask: Task<Void, Never>?
    private var scrollMomentumTask: Task<Void, Never>?
    private var scrollMomentumSeedTracker = ScrollMomentumSeedTracker()
    private let scrollMomentumPlanner = ScrollMomentumPlanner()
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
                deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "ios-device",
                deviceName: UIDevice.current.name
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
                deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "ios-device",
                deviceName: UIDevice.current.name
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

    func disconnect() {
        stopLatencyUpdates()
        stopScrollMomentum()
        client.disconnect()
        mapper.end()
        connectionState = .disconnected
    }

    func touchBegan(with contacts: [TouchContact]) {
        guard isConnected else {
            return
        }

        applyGestureConfiguration()
        stopScrollMomentum()
        send(mapper.begin(with: contacts))
    }

    func touchMoved(with contacts: [TouchContact]) {
        guard isConnected else {
            return
        }

        applyGestureConfiguration()
        touchMoveSampleCounter += 1
        send(mapper.move(with: contacts))
    }

    func touchEnded(with contacts: [TouchContact]) {
        applyGestureConfiguration()
        guard isConnected else {
            mapper.end()
            return
        }

        send(mapper.end(with: contacts))
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

        processScrollState(from: events)
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

    private func processScrollState(from events: [InputEvent]) {
        for event in events {
            guard case .scroll(let scroll) = event.kind else {
                continue
            }

            switch scroll.phase {
            case .began, .changed:
                scrollMomentumSeedTracker.record(scroll: scroll, velocity: mapper.lastScrollVelocity)
            case .ended:
                startScrollMomentumIfNeeded()
            }
        }
    }

    private func startScrollMomentumIfNeeded() {
        guard let seedVelocity = scrollMomentumSeedTracker.seedVelocity() else {
            return
        }

        startScrollMomentum(steps: scrollMomentumPlanner.steps(
            initialVelocityDxPerSecond: seedVelocity.dxPerSecond,
            initialVelocityDyPerSecond: seedVelocity.dyPerSecond,
            amount: scrollMomentumAmount
        ))
    }

    private func startScrollMomentum(steps: [ScrollMomentumStep]) {
        guard !steps.isEmpty else {
            clearScrollMomentumSeed()
            return
        }

        stopScrollMomentum()
        scrollMomentumTask = Task { [weak self] in
            var previousDelay: UInt64 = 0
            for step in steps {
                guard !Task.isCancelled else {
                    return
                }

                let delay = step.delayNanos > previousDelay ? step.delayNanos - previousDelay : 0
                previousDelay = step.delayNanos
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled else {
                    return
                }

                await MainActor.run {
                    self?.sendMomentumScrollStep(step)
                }
            }
        }
        clearScrollMomentumSeed()
    }

    private func sendMomentumScrollStep(_ step: ScrollMomentumStep) {
        guard isConnected else {
            return
        }

        let event = mapper.makeMomentumScrollEvent(dx: step.dx, dy: step.dy, phase: step.phase)
        sentEventCounter += 1
        do {
            try client.enqueue([event])
        } catch {
            handleInputSendFailure(String(describing: error))
        }
    }

    private func stopScrollMomentum() {
        scrollMomentumTask?.cancel()
        scrollMomentumTask = nil
        clearScrollMomentumSeed()
    }

    private func clearScrollMomentumSeed() {
        scrollMomentumSeedTracker.reset()
    }

    private func handleInputSendFailure(_ message: String) {
        stopLatencyUpdates()
        stopScrollMomentum()
        connectionState = .failed(message)
        client.disconnect()
    }
}
