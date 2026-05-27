import TrackpadKit

public struct PairingPolicy: Sendable {
    public let requiredCode: PairingCode

    public init(requiredCode: PairingCode) {
        self.requiredCode = requiredCode
    }

    public func validate(_ hello: ClientHello) -> PairingDecision {
        guard hello.protocolVersion == 1 else {
            return .rejected("unsupported protocol version")
        }

        guard hello.pairingCode == requiredCode.value else {
            return .rejected("invalid pairing code")
        }

        return .accepted
    }
}

public enum PairingDecision: Equatable, Sendable {
    case accepted
    case rejected(String)
}

