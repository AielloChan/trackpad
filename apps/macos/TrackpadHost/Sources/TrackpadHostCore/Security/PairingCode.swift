import Foundation

public struct PairingCode: Equatable, Sendable {
    public let value: String

    public init(_ value: String) {
        self.value = String(value.prefix(6))
    }

    public static func generate() -> PairingCode {
        PairingCode(String(format: "%06d", Int.random(in: 0...999_999)))
    }
}

