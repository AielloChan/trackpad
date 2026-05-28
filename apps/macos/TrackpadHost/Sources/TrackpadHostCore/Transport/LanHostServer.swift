import Foundation
import Network
import TrackpadKit

public final class LanHostServer: @unchecked Sendable {
    public typealias StatusHandler = @Sendable (HostRuntimeStatus) -> Void

    private let port: UInt16
    private let serviceName: String
    private let processor: HostEventProcessor
    private let pairingPolicy: PairingPolicy
    private let statusHandler: StatusHandler
    private let logger: any HostLogging
    private let clientLogUploadWriter: ClientLogUploadWriter
    private let inputCompactor = RealtimeInputCompactor()
    private let queue = DispatchQueue(label: "trackpad.host.lan-server", qos: .userInteractive)

    private var listener: NWListener?
    private var connections: [UUID: NWConnection] = [:]
    private var codecs: [UUID: SessionStreamCodec] = [:]
    private var authorizedConnections: Set<UUID> = []
    private var status = HostRuntimeStatus.stopped

    public init(
        port: UInt16 = HostDefaults.tcpPort,
        serviceName: String = HostDefaults.bonjourName,
        pairingPolicy: PairingPolicy,
        processor: HostEventProcessor,
        clientLogUploadWriter: ClientLogUploadWriter = ClientLogUploadWriter(),
        logger: any HostLogging = DisabledHostLogger(),
        statusHandler: @escaping StatusHandler = { _ in }
    ) {
        self.port = port
        self.serviceName = serviceName
        self.pairingPolicy = pairingPolicy
        self.processor = processor
        self.clientLogUploadWriter = clientLogUploadWriter
        self.statusHandler = statusHandler
        self.logger = logger
    }

    public func start() throws {
        guard listener == nil else {
            return
        }

        logger.info(category: "server", "starting port=\(port) service=\(serviceName)")
        updateStatus(state: .starting)

        let parameters = Self.lowLatencyTCPParameters()
        parameters.allowLocalEndpointReuse = true

        let listener = try NWListener(
            using: parameters,
            on: NWEndpoint.Port(rawValue: port)!
        )
        listener.service = NWListener.Service(
            name: serviceName,
            type: HostDefaults.bonjourType
        )

        listener.stateUpdateHandler = { [weak self] state in
            self?.handleListenerState(state)
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }

        self.listener = listener
        listener.start(queue: queue)
    }

    public func stop() {
        queue.sync {
            self.logger.info(category: "server", "stopping connections=\(self.connections.count)")
            listener?.cancel()
            listener = nil

            for connection in connections.values {
                connection.cancel()
            }

            connections.removeAll()
            codecs.removeAll()
            authorizedConnections.removeAll()
            updateStatus(state: .stopped, clearLastError: true)
        }
    }

    public func requestClientLogUpload(reason: String = "host requested diagnostics") {
        queue.async {
            let request = HostLogRequest(
                id: UUID().uuidString,
                requestedAtNanos: Self.currentTimestampNanos(),
                reason: reason
            )
            let connectionIDs = Array(self.authorizedConnections)
            self.logger.info(category: "client-log", "request id=\(request.id) connections=\(connectionIDs.count) reason=\(reason)")
            for id in connectionIDs {
                self.send(.hostLogRequest(request), to: id)
            }
        }
    }

    private func handleListenerState(_ state: NWListener.State) {
        queue.async {
            switch state {
            case .ready:
                self.logger.info(category: "server", "listener ready port=\(self.port)")
                self.updateStatus(state: .running, clearLastError: true)
            case .failed(let error):
                self.logger.error(category: "server", "listener failed error=\(String(describing: error))")
                self.listener = nil
                self.updateStatus(state: .failed, lastError: String(describing: error))
            case .cancelled:
                self.logger.info(category: "server", "listener cancelled")
                self.listener = nil
                self.updateStatus(state: .stopped)
            default:
                break
            }
        }
    }

    private func accept(_ connection: NWConnection) {
        queue.async {
            let id = UUID()
            self.connections[id] = connection
            self.codecs[id] = SessionStreamCodec()
            self.logger.info(category: "connection", "accepted id=\(id)")
            self.updateStatus(state: self.status.state)

            connection.stateUpdateHandler = { [weak self] state in
                self?.logger.debug(category: "connection", "state id=\(id) state=\(String(describing: state))")
                if case .cancelled = state {
                    self?.removeConnection(id)
                } else if case .failed = state {
                    self?.removeConnection(id)
                }
            }

            connection.start(queue: self.queue)
            self.receive(from: connection, id: id)
        }
    }

    private func receive(from connection: NWConnection, id: UUID) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else {
                return
            }

            self.queue.async {
                var shouldContinue = true
                if let data, !data.isEmpty {
                    shouldContinue = self.handle(data, from: id)
                }

                if isComplete || error != nil || !shouldContinue {
                    self.removeConnection(id)
                    return
                }

                self.receive(from: connection, id: id)
            }
        }
    }

    private func handle(_ data: Data, from id: UUID) -> Bool {
        do {
            var codec = codecs[id] ?? SessionStreamCodec()
            let messages = inputCompactor.compact(try codec.append(data))
            codecs[id] = codec

            for message in messages {
                guard handle(message, from: id) else {
                    return false
                }
            }

            if !messages.isEmpty {
                updateStatus(state: status.state)
            }
            return true
        } catch {
            logger.error(category: "transport", "decode failed connection=\(id) error=\(String(describing: error))")
            updateStatus(state: .failed, lastError: String(describing: error))
            return false
        }
    }

    private func handle(_ message: SessionStreamMessage, from id: UUID) -> Bool {
        switch message {
        case .frame(let frame):
            return handle(frame, from: id)
        case .input(let event):
            return handleInput(event, from: id)
        }
    }

    private func handle(_ frame: SessionFrame, from id: UUID) -> Bool {
        switch frame {
        case .clientHello(let hello):
            switch pairingPolicy.validate(hello) {
            case .accepted:
                authorizedConnections.insert(id)
                logger.info(category: "pairing", "accepted connection=\(id) deviceId=\(hello.deviceId) deviceName=\(hello.deviceName)")
                updateStatus(state: status.state, clearLastError: true)
                return true
            case .rejected(let reason):
                logger.warning(category: "pairing", "rejected connection=\(id) reason=\(reason)")
                updateStatus(state: status.state, lastError: reason)
                return false
            }
        case .input(let event):
            return handleInput(event, from: id)
        case .ping(let ping):
            guard authorizedConnections.contains(id) else {
                logger.warning(category: "latency", "rejected unpaired ping connection=\(id) id=\(ping.id)")
                updateStatus(state: status.state, lastError: "ping received before pairing")
                return false
            }
            logger.debug(category: "latency", "ping connection=\(id) id=\(ping.id)")
            send(
                .pong(
                    SessionPong(
                        id: ping.id,
                        clientSentNanos: ping.clientSentNanos,
                        hostReceivedNanos: Self.currentTimestampNanos()
                    )
                ),
                to: id
            )
            updateStatus(state: status.state, clearLastError: true)
            return true
        case .pong:
            return true
        case .rejected:
            return true
        case .hostLogRequest:
            return true
        case .clientLogUpload(let upload):
            guard authorizedConnections.contains(id) else {
                logger.warning(category: "client-log", "rejected unpaired upload connection=\(id) requestId=\(upload.requestId)")
                updateStatus(state: status.state, lastError: "client log upload received before pairing")
                return false
            }

            do {
                let url = try clientLogUploadWriter.write(upload)
                logger.info(category: "client-log", "received connection=\(id) requestId=\(upload.requestId) path=\(url.path) bytes=\(upload.content.utf8.count) truncated=\(upload.truncated)")
                updateStatus(state: status.state, clearLastError: true)
                return true
            } catch {
                logger.error(category: "client-log", "write failed connection=\(id) requestId=\(upload.requestId) error=\(String(describing: error))")
                updateStatus(state: status.state, lastError: String(describing: error))
                return true
            }
        }
    }

    private func handleInput(_ event: InputEvent, from id: UUID) -> Bool {
        guard authorizedConnections.contains(id) else {
            logger.warning(category: "input", "rejected unpaired input connection=\(id) sequence=\(event.sequenceNumber)")
            updateStatus(state: status.state, lastError: "input received before pairing")
            return false
        }
        logger.debug(category: "input", "received connection=\(id) sequence=\(event.sequenceNumber)")
        processor.handle(event)
        updateStatus(state: status.state, clearLastError: true)
        return true
    }

    private func send(_ frame: SessionFrame, to id: UUID) {
        guard let connection = connections[id] else {
            return
        }

        do {
            let data = try SessionFrameLineCodec.encode(frame)
            connection.send(content: data, completion: .contentProcessed { [weak self] error in
                guard let self, let error else {
                    return
                }

                self.queue.async {
                    self.logger.error(category: "transport", "send failed connection=\(id) error=\(String(describing: error))")
                    self.updateStatus(state: self.status.state, lastError: String(describing: error))
                }
            })
        } catch {
            logger.error(category: "transport", "encode failed connection=\(id) error=\(String(describing: error))")
            updateStatus(state: status.state, lastError: String(describing: error))
        }
    }

    private func removeConnection(_ id: UUID) {
        queue.async {
            self.logger.info(category: "connection", "removed id=\(id)")
            self.connections[id]?.cancel()
            self.connections[id] = nil
            self.codecs[id] = nil
            self.authorizedConnections.remove(id)
            self.updateStatus(state: self.status.state)
        }
    }

    private func updateStatus(
        state: HostRuntimeStatus.State,
        lastError: String? = nil,
        clearLastError: Bool = false
    ) {
        status = HostRuntimeStatus(
            state: state,
            port: port,
            connectionCount: connections.count,
            authorizedConnectionCount: authorizedConnections.count,
            handledEventCount: processor.handledEventCount,
            lastError: clearLastError ? nil : lastError ?? status.lastError
        )
        statusHandler(status)
    }

    private static func currentTimestampNanos() -> UInt64 {
        UInt64(Date().timeIntervalSince1970 * 1_000_000_000)
    }

    private static func lowLatencyTCPParameters() -> NWParameters {
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.noDelay = true
        return NWParameters(tls: nil, tcp: tcpOptions)
    }
}
