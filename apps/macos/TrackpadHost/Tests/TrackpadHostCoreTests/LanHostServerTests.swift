import Foundation
import Network
import Testing
import TrackpadKit
@testable import TrackpadHostCore

@Test func lanHostServerRejectsInvalidPairingBeforeProcessingInput() throws {
    let port = UInt16.random(in: 45_000...55_000)
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
    let port = UInt16.random(in: 45_000...55_000)
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

@Test func lanHostServerRepliesToAuthorizedPingWithPong() throws {
    let port = UInt16.random(in: 45_000...55_000)
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

    private static func encodeFrame(_ frame: SessionFrame) throws -> Data {
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

private extension SessionFrame {
    var pongHostReceivedNanos: UInt64? {
        guard case .pong(let pong) = self else {
            return nil
        }

        return pong.hostReceivedNanos
    }
}
