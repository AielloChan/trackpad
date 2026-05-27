import Foundation
import Network
import TrackpadKit

public enum InputEventClient {
    public static func send(
        _ event: InputEvent,
        host: String = "127.0.0.1",
        port: UInt16 = HostDefaults.tcpPort,
        pairingCode: PairingCode,
        timeout: TimeInterval = 3
    ) throws {
        let hello = ClientHello(
            protocolVersion: 1,
            deviceId: "trackpad-cli",
            deviceName: "Trackpad CLI",
            pairingCode: pairingCode.value
        )
        let data = try SessionFrameLineCodec.encode(.clientHello(hello)) + SessionFrameLineCodec.encode(.input(event))
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: .tcp
        )
        let queue = DispatchQueue(label: "trackpad.host.input-event-client")
        let sendState = InputEventSendState()

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                connection.send(content: data, completion: .contentProcessed { error in
                    sendState.finish(error)
                    connection.cancel()
                })
            case .failed(let error):
                sendState.finish(error)
            default:
                break
            }
        }
        connection.start(queue: queue)

        if sendState.wait(timeout: timeout) == .timedOut {
            connection.cancel()
            throw InputEventClientError.timeout
        }

        if let error = sendState.error {
            throw error
        }
    }
}

public enum InputEventClientError: Error, Equatable {
    case timeout
}

private final class InputEventSendState: @unchecked Sendable {
    private let group = DispatchGroup()
    private let lock = NSLock()
    private(set) var error: (any Error)?
    private var isFinished = false

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
