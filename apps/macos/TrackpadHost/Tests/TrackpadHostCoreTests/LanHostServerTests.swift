import Foundation
import Network
import Testing
import TrackpadKit
@testable import TrackpadHostCore

@Test func lanHostServerRejectsInvalidPairingBeforeProcessingInput() throws {
    let port = nextLanHostServerTestPort()
    let performer = LanServerRecordingInputPerformer()
    let processor = HostEventProcessor(performer: performer)
    let statuses = HostStatusRecorder()
    let server = LanHostServer(
        port: port,
        pairingPolicy: PairingPolicy(requiredCode: PairingCode("654321")),
        processor: processor,
        statusHandler: statuses.record
    )
    try server.start()
    defer {
        server.stop()
    }

    #expect(statuses.waitForStatus(where: { $0.state == .running }) != nil)

    let event = InputEvent(
        sequenceNumber: 100,
        timestampNanos: 1_000,
        kind: .pointerMove(PointerMoveEvent(dx: 9, dy: -6))
    )
    try InputEventClient.send(
        event,
        port: port,
        pairingCode: PairingCode("000000"),
        timeout: 2
    )

    #expect(statuses.waitForStatus(where: { $0.lastError == "invalid pairing code" }) != nil)
    #expect(processor.handledEventCount == 0)
    #expect(performer.commands.isEmpty)
}

@Test func lanHostServerProcessesInputAfterValidPairingAndClearsPreviousError() throws {
    let port = nextLanHostServerTestPort()
    let performer = LanServerRecordingInputPerformer()
    let processor = HostEventProcessor(performer: performer)
    let statuses = HostStatusRecorder()
    let server = LanHostServer(
        port: port,
        pairingPolicy: PairingPolicy(requiredCode: PairingCode("654321")),
        processor: processor,
        statusHandler: statuses.record
    )
    try server.start()
    defer {
        server.stop()
    }

    #expect(statuses.waitForStatus(where: { $0.state == .running }) != nil)

    let event = InputEvent(
        sequenceNumber: 101,
        timestampNanos: 1_001,
        kind: .pointerMove(PointerMoveEvent(dx: 9, dy: -6))
    )
    try InputEventClient.send(
        event,
        port: port,
        pairingCode: PairingCode("000000"),
        timeout: 2
    )
    #expect(statuses.waitForStatus(where: { $0.lastError == "invalid pairing code" }) != nil)

    try InputEventClient.send(
        event,
        port: port,
        pairingCode: PairingCode("654321"),
        timeout: 2
    )

    #expect(statuses.waitForStatus(where: { $0.handledEventCount == 1 && $0.lastError == nil }) != nil)
    #expect(performer.commands == [.move(dx: 9, dy: -6)])
}

@Test func lanHostServerProcessesBinaryInputReportAfterValidPairing() throws {
    let port = nextLanHostServerTestPort()
    let performer = LanServerRecordingInputPerformer()
    let processor = HostEventProcessor(performer: performer)
    let statuses = HostStatusRecorder()
    let server = LanHostServer(
        port: port,
        pairingPolicy: PairingPolicy(requiredCode: PairingCode("654321")),
        processor: processor,
        statusHandler: statuses.record
    )
    try server.start()
    defer {
        server.stop()
    }

    #expect(statuses.waitForStatus(where: { $0.state == .running }) != nil)

    let event = InputEvent(
        sequenceNumber: 102,
        timestampNanos: 1_002,
        kind: .pointerMove(PointerMoveEvent(dx: 4.5, dy: -3.25))
    )
    try InputEventClient.send(
        event,
        port: port,
        pairingCode: PairingCode("654321"),
        timeout: 2
    )

    #expect(statuses.waitForStatus(where: { $0.handledEventCount == 1 && $0.lastError == nil }) != nil)
    #expect(performer.commands == [.move(dx: 4.5, dy: -3.25)])
}

@Test func lanHostServerRepliesToAuthorizedPingWithPong() throws {
    let port = nextLanHostServerTestPort()
    let performer = LanServerRecordingInputPerformer()
    let processor = HostEventProcessor(performer: performer)
    let statuses = HostStatusRecorder()
    let server = LanHostServer(
        port: port,
        pairingPolicy: PairingPolicy(requiredCode: PairingCode("654321")),
        processor: processor,
        statusHandler: statuses.record
    )
    try server.start()
    defer {
        server.stop()
    }

    #expect(statuses.waitForStatus(where: { $0.state == .running }) != nil)

    let frames = try SessionFrameRoundTripClient.send(
        [
            .clientHello(
                ClientHello(
                    protocolVersion: 1,
                    deviceId: "test-client",
                    deviceName: "Test Client",
                    pairingCode: "654321"
                )
            ),
            .ping(SessionPing(id: 9, clientSentNanos: 1_000)),
        ],
        port: port
    )

    #expect(frames == [
        .pong(SessionPong(id: 9, clientSentNanos: 1_000, hostReceivedNanos: frames.first?.pongHostReceivedNanos ?? 0)),
    ])
}

@Test func lanHostServerRequestsAndPersistsClientLogUpload() throws {
    let port = nextLanHostServerTestPort()
    let performer = LanServerRecordingInputPerformer()
    let processor = HostEventProcessor(performer: performer)
    let statuses = HostStatusRecorder()
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let server = LanHostServer(
        port: port,
        pairingPolicy: PairingPolicy(requiredCode: PairingCode("654321")),
        processor: processor,
        clientLogUploadWriter: ClientLogUploadWriter(directoryURL: directory),
        statusHandler: statuses.record
    )
    try server.start()
    defer {
        server.stop()
    }

    #expect(statuses.waitForStatus(where: { $0.state == .running }) != nil)

    let client = ClientLogUploadRoundTripClient(port: port)
    try client.start()
    defer {
        client.stop()
    }

    #expect(statuses.waitForStatus(where: { $0.authorizedConnectionCount == 1 }) != nil)

    server.requestClientLogUpload(reason: "test")

    let uploadedURL = try #require(waitForUploadedClientLog(in: directory))
    let content = try String(contentsOf: uploadedURL, encoding: .utf8)
    #expect(content.contains("requestId="))
    #expect(content.contains("deviceId=test-client"))
    #expect(content.contains("######### ios.client uploaded from test"))
}

private final class HostStatusRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var statuses: [HostRuntimeStatus] = []

    func record(_ status: HostRuntimeStatus) {
        lock.lock()
        statuses.append(status)
        lock.unlock()
    }

    func waitForStatus(
        timeout: TimeInterval = 2,
        where predicate: (HostRuntimeStatus) -> Bool
    ) -> HostRuntimeStatus? {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            lock.lock()
            let match = statuses.last(where: predicate)
            lock.unlock()

            if let match {
                return match
            }

            Thread.sleep(forTimeInterval: 0.01)
        }

        return nil
    }
}

private final class LanServerRecordingInputPerformer: MacInputPerforming {
    private(set) var commands: [MacInputCommand] = []

    func perform(_ command: MacInputCommand) {
        commands.append(command)
    }
}

private final class ClientLogUploadRoundTripClient: @unchecked Sendable {
    private let port: UInt16
    private let queue = DispatchQueue(label: "trackpad.host.tests.client-log-upload-client")
    private let ready = DispatchGroup()
    private var connection: NWConnection?
    private var codec = InputEventLineCodec()

    init(port: UInt16) {
        self.port = port
        ready.enter()
    }

    func start() throws {
        let connection = NWConnection(
            host: "127.0.0.1",
            port: NWEndpoint.Port(rawValue: port)!,
            using: .tcp
        )
        self.connection = connection

        connection.stateUpdateHandler = { [weak self] state in
            guard let self else {
                return
            }

            if case .ready = state {
                do {
                    try self.send(
                        .clientHello(
                            ClientHello(
                                protocolVersion: 1,
                                deviceId: "test-client",
                                deviceName: "Test Client",
                                pairingCode: "654321"
                            )
                        )
                    )
                    self.receiveNext()
                    self.ready.leave()
                } catch {
                    self.ready.leave()
                }
            } else if case .failed = state {
                self.ready.leave()
            }
        }
        connection.start(queue: queue)

        if ready.wait(timeout: .now() + 2) == .timedOut {
            throw InputEventClientError.timeout
        }
    }

    func stop() {
        connection?.cancel()
    }

    private func receiveNext() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self, error == nil, !isComplete else {
                return
            }

            if let data, !data.isEmpty,
               let frames = try? self.codec.append(data) {
                for frame in frames {
                    if case .hostLogRequest(let request) = frame {
                        try? self.send(
                            .clientLogUpload(
                                ClientLogUpload(
                                    requestId: request.id,
                                    deviceId: "test-client",
                                    deviceName: "Test Client",
                                    createdAtNanos: 2_000,
                                    content: "######### ios.client uploaded from test",
                                    truncated: false
                                )
                            )
                        )
                    }
                }
            }

            self.receiveNext()
        }
    }

    private func send(_ frame: SessionFrame) throws {
        let data = try SessionFrameRoundTripClient.encodeFrame(frame)
        connection?.send(content: data, completion: .contentProcessed { _ in })
    }
}

private func waitForUploadedClientLog(in directory: URL, timeout: TimeInterval = 2) -> URL? {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ), let first = urls.first {
            return first
        }

        Thread.sleep(forTimeInterval: 0.01)
    }

    return nil
}

private enum SessionFrameRoundTripClient {
    static func send(_ frames: [SessionFrame], port: UInt16, timeout: TimeInterval = 2) throws -> [SessionFrame] {
        let data = try frames.reduce(into: Data()) { result, frame in
            result.append(try encodeFrame(frame))
        }
        let connection = NWConnection(
            host: "127.0.0.1",
            port: NWEndpoint.Port(rawValue: port)!,
            using: .tcp
        )
        let queue = DispatchQueue(label: "trackpad.host.tests.round-trip-client")
        let state = SessionFrameRoundTripState()

        connection.stateUpdateHandler = { nwState in
            if case .ready = nwState {
                connection.send(content: data, completion: .contentProcessed { error in
                    if let error {
                        state.finish(error)
                        return
                    }

                    receive(on: connection, state: state)
                })
            } else if case .failed(let error) = nwState {
                state.finish(error)
            }
        }
        connection.start(queue: queue)

        if state.wait(timeout: timeout) == .timedOut {
            connection.cancel()
            throw InputEventClientError.timeout
        }

        connection.cancel()

        if let error = state.error {
            throw error
        }

        return state.frames
    }

    private static func receive(on connection: NWConnection, state: SessionFrameRoundTripState) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, _, error in
            if let error {
                state.finish(error)
                return
            }

            if let data, !data.isEmpty {
                do {
                    state.append(try data.decodedSessionFrames())
                } catch {
                    state.finish(error)
                }
            }
        }
    }

    fileprivate static func encodeFrame(_ frame: SessionFrame) throws -> Data {
        var data = try JSONEncoder().encode(frame)
        data.append(UInt8(ascii: "\n"))
        return data
    }
}

private final class SessionFrameRoundTripState: @unchecked Sendable {
    private let group = DispatchGroup()
    private let lock = NSLock()
    private(set) var frames: [SessionFrame] = []
    private(set) var error: (any Error)?
    private var isFinished = false

    init() {
        group.enter()
    }

    func append(_ frames: [SessionFrame]) {
        lock.lock()
        self.frames.append(contentsOf: frames)
        finishLocked(nil)
        lock.unlock()
    }

    func finish(_ error: (any Error)?) {
        lock.lock()
        finishLocked(error)
        lock.unlock()
    }

    func wait(timeout: TimeInterval) -> DispatchTimeoutResult {
        group.wait(timeout: .now() + timeout)
    }

    private func finishLocked(_ error: (any Error)?) {
        guard !isFinished else {
            return
        }

        self.error = error
        isFinished = true
        group.leave()
    }
}

private extension Data {
    func decodedSessionFrames() throws -> [SessionFrame] {
        try split(separator: UInt8(ascii: "\n")).map { line in
            try JSONDecoder().decode(SessionFrame.self, from: Data(line))
        }
    }
}

private let lanHostServerTestPortAllocator = LanHostServerTestPortAllocator(start: 45_000)

private func nextLanHostServerTestPort() -> UInt16 {
    lanHostServerTestPortAllocator.next()
}

private final class LanHostServerTestPortAllocator: @unchecked Sendable {
    private let lock = NSLock()
    private var nextPort: UInt16

    init(start: UInt16) {
        nextPort = start
    }

    func next() -> UInt16 {
        lock.lock()
        defer { lock.unlock() }

        let port = nextPort
        nextPort += 1
        return port
    }
}

private extension SessionFrame {
    var pongHostReceivedNanos: UInt64? {
        guard case .pong(let pong) = self else {
            return nil
        }

        return pong.hostReceivedNanos
    }
}
