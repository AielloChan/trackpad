import Testing
import TrackpadKit
@testable import TrackpadHostCore

@Test func generatedPairingCodeContainsSixDigits() {
    let code = PairingCode.generate()

    #expect(code.value.count == 6)
    #expect(code.value.allSatisfy { $0.isNumber })
}

@Test func pairingPolicyAcceptsMatchingHello() {
    let policy = PairingPolicy(requiredCode: PairingCode("123456"))
    let hello = ClientHello(
        protocolVersion: 1,
        deviceId: "ios-device-1",
        deviceName: "iPhone",
        pairingCode: "123456"
    )

    #expect(policy.validate(hello) == .accepted)
}

@Test func pairingPolicyRejectsMismatchedCode() {
    let policy = PairingPolicy(requiredCode: PairingCode("123456"))
    let hello = ClientHello(
        protocolVersion: 1,
        deviceId: "ios-device-1",
        deviceName: "iPhone",
        pairingCode: "654321"
    )

    #expect(policy.validate(hello) == .rejected("invalid pairing code"))
}
