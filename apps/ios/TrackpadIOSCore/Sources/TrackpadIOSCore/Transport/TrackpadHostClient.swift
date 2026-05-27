import Foundation
import Network
#if SWIFT_PACKAGE
import TrackpadKit
#endif

public final class TrackpadHostClient: @unchecked Sendable {
    public var inputSendFailureHandler: (@Sendable (String) -> Void)?

    private let queue = DispatchQueue(label: "trackpad.ios.host-client")
    private var connection: NWConnection?
    private var receiveCodec = SessionFrameLineCodec()
    private var sendBuffer = InputEventSendBuffer()
    private var nextPingID: UInt64 = 1
    private var pendingLatencyProbes: [UInt64: PendingLatencyProbe] = [:]

    public init() {}

    public func connect(configuration: TrackpadConnectionConfiguration, timeout: TimeInterval = 3) async throws {
        disconnect()

        let connection = NWConnection(to: configuration.address.connectionEndpoint, using: Self.lowLatencyTCPParameters())
        let readyState = ConnectionReadyState()
        queue.sync {
            self.connection = connection
            receiveCodec = SessionFrameLineCodec()
            sendBuffer = InputEventSendBuffer()
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

        connection.start(queue: queue)

        if readyState.wait(timeout: timeout) == .timedOut {
            connection.cancel()
            throw TrackpadHostClientError.timeout
        }

        if let error = readyState.error {
            throw error
        }

        receiveNext(on: connection)
        try await send(TrackpadSessionMessageBuilder.clientHelloData(for: configuration))
    }

    public func send(_ event: InputEvent) async throws {
        try await send(TrackpadSessionMessageBuilder.inputData(for: event))
    }

    public func enqueue(_ events: [InputEvent]) throws {
        guard !events.isEmpty else {
            return
        }

        let data = try events.reduce(into: Data()) { result, event in
            result.append(try TrackpadSessionMessageBuilder.inputData(for: event))
        }

        queue.async {
            guard self.connection != nil else {
                self.inputSendFailureHandler?(String(describing: TrackpadHostClientError.notConnected))
                return
            }

            if let batch = self.sendBuffer.enqueue(data) {
                self.sendBufferedData(batch)
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
            sendBuffer = InputEventSendBuffer()
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

    private func sendBufferedData(_ data: Data) {
        guard let connection else {
            inputSendFailureHandler?(String(describing: TrackpadHostClientError.notConnected))
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
                    self.sendBufferedData(nextBatch)
                }
            }
        })
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
        case .clientHello, .input, .ping:
            break
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

    private static func lowLatencyTCPParameters() -> NWParameters {
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.noDelay = true
        return NWParameters(tls: nil, tcp: tcpOptions)
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

struct InputEventSendBuffer {
    private var isSending = false
    private var pendingData = Data()

    mutating func enqueue(_ data: Data) -> Data? {
        guard !data.isEmpty else {
            return nil
        }

        pendingData.append(data)
        guard !isSending else {
            return nil
        }

        return drainNextBatch()
    }

    mutating func completeCurrentSend() -> Data? {
        isSending = false
        return drainNextBatch()
    }

    private mutating func drainNextBatch() -> Data? {
        guard !pendingData.isEmpty else {
            return nil
        }

        let data = pendingData
        pendingData.removeAll(keepingCapacity: true)
        isSending = true
        return data
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
