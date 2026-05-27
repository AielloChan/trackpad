import TrackpadProtocol

public protocol Transport: Sendable {
    func send(_ event: InputEvent) async throws
}
