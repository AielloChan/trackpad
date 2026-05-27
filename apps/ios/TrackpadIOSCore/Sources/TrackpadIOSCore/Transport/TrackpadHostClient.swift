import Foundation
import Network
#if SWIFT_PACKAGE
import TrackpadKit
#endif

public final class TrackpadHostClient: @unchecked Sendable {
    public var inputSendFailureHandler: (@Sendable (String) -> Void)?
    public var pathUpdateHandler: (@Sendable (NetworkPathSnapshot) -> Void)?
    public var connectionAttemptHandler: (@Sendable (TrackpadConnectionAttemptDiagnostic) -> Void)?
    public var logUploadProvider: (@Sendable (HostLogRequest) -> ClientLogUpload?)?
    public var connectionAttemptPlan = TrackpadConnectionAttemptPlan()

    private let queue = DispatchQueue(label: "trackpad.ios.host-client")
    private var connection: NWConnection?
    private var receiveCodec = SessionFrameLineCodec()
    private var sendBuffer = InputReportSendBuffer()
    private var nextPingID: UInt64 = 1
    private var pendingLatencyProbes: [UInt64: PendingLatencyProbe] = [:]

    public init() {}

    public func connect(configuration: TrackpadConnectionConfiguration, timeout: TimeInterval = 3) async throws {
        disconnect()

        var lastError: (any Error)?
        for attempt in connectionAttemptPlan.attempts(defaultTimeout: timeout) {
            do {
                try await connect(configuration: configuration, attempt: attempt)
                return
            } catch {
                lastError = error
            }
        }

        throw lastError ?? TrackpadHostClientError.timeout
    }

    private func connect(configuration: TrackpadConnectionConfiguration, attempt: TrackpadConnectionAttempt) async throws {
        connectionAttemptHandler?(TrackpadConnectionAttemptDiagnostic(attempt: attempt, phase: .started, errorDescription: nil))
        let connection = NWConnection(
            to: configuration.address.connectionEndpoint,
            using: Self.lowLatencyTCPParameters(requiredInterface: attempt.interfaceRequirement)
        )
        let readyState = ConnectionReadyState()
        queue.sync {
            self.connection = connection
            receiveCodec = SessionFrameLineCodec()
            sendBuffer = InputReportSendBuffer()
        }

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                readyState.finish(nil)
            case .failed(let error):
                readyState.finish(error)
            case .cancelled:
                readyState.finish(TrackpadHostClientError.cancelled)
            default:
                break
            }
        }
        connection.pathUpdateHandler = { [weak self] path in
            self?.pathUpdateHandler?(NetworkPathSnapshot(path: path))
        }

        connection.start(queue: queue)

        if readyState.wait(timeout: attempt.timeout) == .timedOut {
            connection.cancel()
            clearConnectionIfCurrent(connection)
            connectionAttemptHandler?(TrackpadConnectionAttemptDiagnostic(attempt: attempt, phase: .failed, errorDescription: String(describing: TrackpadHostClientError.timeout)))
            throw TrackpadHostClientError.timeout
        }

        if let error = readyState.error {
            connection.cancel()
            clearConnectionIfCurrent(connection)
            connectionAttemptHandler?(TrackpadConnectionAttemptDiagnostic(attempt: attempt, phase: .failed, errorDescription: String(describing: error)))
            throw error
        }

        receiveNext(on: connection)
        do {
            try await send(TrackpadSessionMessageBuilder.clientHelloData(for: configuration))
            connectionAttemptHandler?(TrackpadConnectionAttemptDiagnostic(attempt: attempt, phase: .succeeded, errorDescription: nil))
        } catch {
            connection.cancel()
            clearConnectionIfCurrent(connection)
            connectionAttemptHandler?(TrackpadConnectionAttemptDiagnostic(attempt: attempt, phase: .failed, errorDescription: String(describing: error)))
            throw error
        }
    }

    public func send(_ event: InputEvent) async throws {
        try await send(TrackpadSessionMessageBuilder.inputData(for: event))
    }

    public func enqueue(_ events: [InputEvent]) throws {
        guard !events.isEmpty else {
            return
        }

        let reports = try events.map { try InputReport(event: $0) }

        queue.async {
            guard self.connection != nil else {
                self.inputSendFailureHandler?(String(describing: TrackpadHostClientError.notConnected))
                return
            }

            if let batch = self.sendBuffer.enqueue(reports) {
                self.sendBufferedReports(batch)
            }
        }
    }

    public func measureLatency(timeout: TimeInterval = 2) async throws -> TimeInterval {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TimeInterval, any Error>) in
            queue.async {
                guard let connection = self.connection else {
                    continuation.resume(throwing: TrackpadHostClientError.notConnected)
                    return
                }

                let ping = SessionPing(
                    id: self.nextPingID,
                    clientSentNanos: Self.currentTimestampNanos()
                )
                self.nextPingID &+= 1

                do {
                    self.pendingLatencyProbes[ping.id] = PendingLatencyProbe(continuation: continuation)
                    let data = try TrackpadSessionMessageBuilder.pingData(for: ping)
                    connection.send(content: data, completion: .contentProcessed { [weak self] error in
                        guard let self, let error else {
                            return
                        }

                        self.queue.async {
                            self.finishLatencyProbe(id: ping.id, result: .failure(error))
                        }
                    })

                    self.queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
                        self?.finishLatencyProbe(id: ping.id, result: .failure(TrackpadHostClientError.timeout))
                    }
                } catch {
                    self.finishLatencyProbe(id: ping.id, result: .failure(error))
                }
            }
        }
    }

    public func disconnect() {
        queue.sync {
            connection?.cancel()
            connection = nil
            receiveCodec = SessionFrameLineCodec()
            sendBuffer = InputReportSendBuffer()
            finishAllLatencyProbes(result: .failure(TrackpadHostClientError.cancelled))
        }
    }

    private func send(_ data: Data) async throws {
        guard let connection = queue.sync(execute: { connection }) else {
            throw TrackpadHostClientError.notConnected
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func sendBufferedReports(_ reports: [InputReport]) {
        guard let connection else {
            inputSendFailureHandler?(String(describing: TrackpadHostClientError.notConnected))
            return
        }

        let data: Data
        do {
            data = try reports.reduce(into: Data()) { result, report in
                result.append(try InputReportBinaryCodec.encode(report))
            }
        } catch {
            inputSendFailureHandler?(String(describing: error))
            return
        }

        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            guard let self else {
                return
            }

            self.queue.async {
                if let error {
                    self.inputSendFailureHandler?(String(describing: error))
                    return
                }

                if let nextBatch = self.sendBuffer.completeCurrentSend() {
                    self.sendBufferedReports(nextBatch)
                }
            }
        })
    }

    private func clearConnectionIfCurrent(_ connection: NWConnection) {
        queue.sync {
            if self.connection === connection {
                self.connection = nil
            }
        }
    }

    private func receiveNext(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else {
                return
            }

            self.queue.async {
                guard self.connection === connection else {
                    return
                }

                if let data, !data.isEmpty {
                    do {
                        let frames = try self.receiveCodec.append(data)
                        for frame in frames {
                            self.handle(frame)
                        }
                    } catch {
                        self.finishAllLatencyProbes(result: .failure(error))
                        connection.cancel()
                        self.connection = nil
                        return
                    }
                }

                if let error {
                    self.finishAllLatencyProbes(result: .failure(error))
                    self.connection = nil
                    return
                }

                if isComplete {
                    self.finishAllLatencyProbes(result: .failure(TrackpadHostClientError.cancelled))
                    self.connection = nil
                    return
                }

                self.receiveNext(on: connection)
            }
        }
    }

    private func handle(_ frame: SessionFrame) {
        switch frame {
        case .pong(let pong):
            let currentNanos = Self.currentTimestampNanos()
            let roundTripNanos = currentNanos >= pong.clientSentNanos ? currentNanos - pong.clientSentNanos : 0
            let roundTripSeconds = TimeInterval(roundTripNanos) / 1_000_000_000
            finishLatencyProbe(id: pong.id, result: .success(roundTripSeconds))
        case .rejected:
            finishAllLatencyProbes(result: .failure(TrackpadHostClientError.cancelled))
        case .hostLogRequest(let request):
            sendClientLogUpload(for: request)
        case .clientHello, .input, .ping, .clientLogUpload:
            break
        }
    }

    private func sendClientLogUpload(for request: HostLogRequest) {
        guard let upload = logUploadProvider?(request) else {
            return
        }

        do {
            let data = try TrackpadSessionMessageBuilder.clientLogUploadData(for: upload)
            guard let connection else {
                inputSendFailureHandler?(String(describing: TrackpadHostClientError.notConnected))
                return
            }

            connection.send(content: data, completion: .contentProcessed { [weak self] error in
                guard let self, let error else {
                    return
                }

                self.queue.async {
                    self.inputSendFailureHandler?(String(describing: error))
                }
            })
        } catch {
            inputSendFailureHandler?(String(describing: error))
        }
    }

    private func finishLatencyProbe(id: UInt64, result: Result<TimeInterval, any Error>) {
        guard let probe = pendingLatencyProbes.removeValue(forKey: id) else {
            return
        }

        switch result {
        case .success(let latency):
            probe.continuation.resume(returning: latency)
        case .failure(let error):
            probe.continuation.resume(throwing: error)
        }
    }

    private func finishAllLatencyProbes(result: Result<TimeInterval, any Error>) {
        let probeIDs = Array(pendingLatencyProbes.keys)
        for id in probeIDs {
            finishLatencyProbe(id: id, result: result)
        }
    }

    private static func currentTimestampNanos() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }

    private static func lowLatencyTCPParameters(requiredInterface: NetworkInterfaceKind? = nil) -> NWParameters {
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.noDelay = true
        let parameters = NWParameters(tls: nil, tcp: tcpOptions)
        if let interfaceType = requiredInterface?.nwInterfaceType {
            parameters.requiredInterfaceType = interfaceType
        }
        return parameters
    }
}

public struct TrackpadConnectionAttempt: Equatable, Sendable {
    public let interfaceRequirement: NetworkInterfaceKind?
    public let timeout: TimeInterval

    public init(interfaceRequirement: NetworkInterfaceKind?, timeout: TimeInterval) {
        self.interfaceRequirement = interfaceRequirement
        self.timeout = timeout
    }

    public var label: String {
        interfaceRequirement?.label ?? "Default"
    }
}

public struct TrackpadConnectionAttemptPlan: Equatable, Sendable {
    public let prefersWiredEthernet: Bool
    public let wiredAttemptTimeout: TimeInterval

    public init(prefersWiredEthernet: Bool = true, wiredAttemptTimeout: TimeInterval = 0.6) {
        self.prefersWiredEthernet = prefersWiredEthernet
        self.wiredAttemptTimeout = wiredAttemptTimeout
    }

    public func attempts(defaultTimeout: TimeInterval) -> [TrackpadConnectionAttempt] {
        guard prefersWiredEthernet else {
            return [TrackpadConnectionAttempt(interfaceRequirement: nil, timeout: defaultTimeout)]
        }

        return [
            TrackpadConnectionAttempt(interfaceRequirement: .wiredEthernet, timeout: min(wiredAttemptTimeout, defaultTimeout)),
            TrackpadConnectionAttempt(interfaceRequirement: nil, timeout: defaultTimeout),
        ]
    }
}

public enum TrackpadConnectionAttemptPhase: String, Equatable, Sendable {
    case started
    case succeeded
    case failed
}

public struct TrackpadConnectionAttemptDiagnostic: Equatable, Sendable {
    public let attempt: TrackpadConnectionAttempt
    public let phase: TrackpadConnectionAttemptPhase
    public let errorDescription: String?

    public init(
        attempt: TrackpadConnectionAttempt,
        phase: TrackpadConnectionAttemptPhase,
        errorDescription: String?
    ) {
        self.attempt = attempt
        self.phase = phase
        self.errorDescription = errorDescription
    }

    public var message: String {
        if let errorDescription {
            return "connect attempt=\(attempt.label) phase=\(phase.rawValue) timeout=\(String(format: "%.2f", attempt.timeout)) error=\(errorDescription)"
        }

        return "connect attempt=\(attempt.label) phase=\(phase.rawValue) timeout=\(String(format: "%.2f", attempt.timeout))"
    }
}

private extension NetworkInterfaceKind {
    var nwInterfaceType: NWInterface.InterfaceType? {
        switch self {
        case .wiredEthernet:
            return .wiredEthernet
        case .wifi:
            return .wifi
        case .cellular:
            return .cellular
        case .loopback:
            return .loopback
        case .other:
            return .other
        }
    }
}

public enum TrackpadHostClientError: Error, Equatable {
    case cancelled
    case notConnected
    case timeout
}

private struct PendingLatencyProbe {
    let continuation: CheckedContinuation<TimeInterval, any Error>
}

struct InputReportSendBuffer {
    private var isSending = false
    private var pendingReports: [InputReport] = []

    mutating func enqueue(_ reports: [InputReport]) -> [InputReport]? {
        guard !reports.isEmpty else {
            return nil
        }

        appendPending(reports)
        guard !isSending else {
            return nil
        }

        return drainNextBatch()
    }

    mutating func completeCurrentSend() -> [InputReport]? {
        isSending = false
        return drainNextBatch()
    }

    private mutating func drainNextBatch() -> [InputReport]? {
        guard !pendingReports.isEmpty else {
            return nil
        }

        let reports = pendingReports
        pendingReports.removeAll(keepingCapacity: true)
        isSending = true
        return reports
    }

    private mutating func appendPending(_ reports: [InputReport]) {
        for report in reports {
            if let last = pendingReports.last,
               let coalesced = last.coalesced(with: report) {
                pendingReports[pendingReports.count - 1] = coalesced
            } else {
                pendingReports.append(report)
            }
        }
    }
}

private extension InputReport {
    func coalesced(with next: InputReport) -> InputReport? {
        switch (kind, next.kind) {
        case (.pointerMove(let dx, let dy), .pointerMove(let nextDx, let nextDy)):
            return InputReport(
                sequenceNumber: next.sequenceNumber,
                timestampNanos: next.timestampNanos,
                kind: .pointerMove(dx: dx + nextDx, dy: dy + nextDy)
            )
        case (
            .scroll(let dx, let dy, let phase, let momentumPhase),
            .scroll(let nextDx, let nextDy, let nextPhase, let nextMomentumPhase)
        ) where phase == .changed && nextPhase == .changed && momentumPhase == nextMomentumPhase:
            return InputReport(
                sequenceNumber: next.sequenceNumber,
                timestampNanos: next.timestampNanos,
                kind: .scroll(
                    dx: dx + nextDx,
                    dy: dy + nextDy,
                    phase: nextPhase,
                    momentumPhase: nextMomentumPhase
                )
            )
        default:
            return nil
        }
    }
}

private final class ConnectionReadyState: @unchecked Sendable {
    private let group = DispatchGroup()
    private let lock = NSLock()
    private var isFinished = false
    private(set) var error: (any Error)?

    init() {
        group.enter()
    }

    func finish(_ error: (any Error)?) {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard !isFinished else {
            return
        }

        self.error = error
        isFinished = true
        group.leave()
    }

    func wait(timeout: TimeInterval) -> DispatchTimeoutResult {
        group.wait(timeout: .now() + timeout)
    }
}
