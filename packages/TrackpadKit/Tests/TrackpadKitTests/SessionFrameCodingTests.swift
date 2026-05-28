import Foundation
import Testing
@testable import TrackpadKit

@Test func clientHelloFrameRoundTripsThroughJSON() throws {
    let frame = SessionFrame.clientHello(
        ClientHello(
            protocolVersion: 1,
            deviceId: "ios-device-1",
            deviceName: "iPhone",
            pairingCode: "123456",
            trustedClientKey: "client-key"
        )
    )

    let data = try JSONEncoder().encode(frame)
    let decoded = try JSONDecoder().decode(SessionFrame.self, from: data)

    #expect(decoded == frame)
}

@Test func trustedClientKeyFrameRoundTripsThroughJSON() throws {
    let key = TrustedClientKey(
        deviceId: "ios-device-1",
        clientKey: "generated-client-key",
        issuedAtNanos: 1_000
    )
    let frame = SessionFrame.trustedClientKey(key)

    let data = try JSONEncoder().encode(frame)
    let decoded = try JSONDecoder().decode(SessionFrame.self, from: data)

    #expect(decoded == frame)
}

@Test func inputFrameRoundTripsThroughJSON() throws {
    let event = InputEvent(
        sequenceNumber: 1,
        timestampNanos: 100,
        kind: .pointerMove(PointerMoveEvent(dx: 10, dy: -2))
    )
    let frame = SessionFrame.input(event)

    let data = try JSONEncoder().encode(frame)
    let decoded = try JSONDecoder().decode(SessionFrame.self, from: data)

    #expect(decoded == frame)
}

@Test func rejectedFrameRoundTripsThroughJSON() throws {
    let frame = SessionFrame.rejected(
        SessionRejected(reason: "invalid pairing code")
    )

    let data = try JSONEncoder().encode(frame)
    let decoded = try JSONDecoder().decode(SessionFrame.self, from: data)

    #expect(decoded == frame)
}

@Test func pingFrameRoundTripsThroughJSON() throws {
    let frame = SessionFrame.ping(SessionPing(id: 42, clientSentNanos: 1_000))

    let data = try JSONEncoder().encode(frame)
    let decoded = try JSONDecoder().decode(SessionFrame.self, from: data)

    #expect(decoded == frame)
}

@Test func pongFrameRoundTripsThroughJSON() throws {
    let frame = SessionFrame.pong(SessionPong(id: 42, clientSentNanos: 1_000, hostReceivedNanos: 2_000))

    let data = try JSONEncoder().encode(frame)
    let decoded = try JSONDecoder().decode(SessionFrame.self, from: data)

    #expect(decoded == frame)
}

@Test func hostLogRequestFrameRoundTripsThroughJSON() throws {
    let frame = SessionFrame.hostLogRequest(
        HostLogRequest(id: "request-1", requestedAtNanos: 1_000, reason: "debug pointer jump")
    )

    let data = try JSONEncoder().encode(frame)
    let decoded = try JSONDecoder().decode(SessionFrame.self, from: data)

    #expect(decoded == frame)
}

@Test func clientLogUploadFrameRoundTripsThroughJSON() throws {
    let frame = SessionFrame.clientLogUpload(
        ClientLogUpload(
            requestId: "request-1",
            deviceId: "ios-device-1",
            deviceName: "iPad",
            createdAtNanos: 2_000,
            content: "######### ios.client example",
            truncated: false
        )
    )

    let data = try JSONEncoder().encode(frame)
    let decoded = try JSONDecoder().decode(SessionFrame.self, from: data)

    #expect(decoded == frame)
}

@Test func scrollMomentumSettingsFrameRoundTripsThroughJSON() throws {
    let frame = SessionFrame.scrollMomentumSettings(
        ScrollMomentumSettings(
            amount: 1.4,
            decayRate: 0.9,
            tailWindowMilliseconds: 120
        )
    )

    let data = try JSONEncoder().encode(frame)
    let decoded = try JSONDecoder().decode(SessionFrame.self, from: data)

    #expect(decoded == frame)
}

@Test func configurationSyncFrameRoundTripsThroughJSON() throws {
    let configuration = TrackpadConfiguration(
        pointer: PointerConfiguration(speedMultiplier: 2.1),
        gestures: GestureConfiguration(
            tapMaximumDurationMilliseconds: 250,
            tapDragMaximumIntervalMilliseconds: 140,
            scrollReleaseTapSuppressionMilliseconds: 80
        ),
        scrollMomentum: ScrollMomentumSettings(
            amount: 1.2,
            decayRate: 0.88,
            tailWindowMilliseconds: 120
        )
    )
    let frame = SessionFrame.configurationSync(
        ConfigurationSyncSnapshot(
            revision: 7,
            updatedAtNanos: 42,
            sourceDeviceId: "ios-1",
            configuration: configuration
        )
    )

    let data = try JSONEncoder().encode(frame)
    let decoded = try JSONDecoder().decode(SessionFrame.self, from: data)

    #expect(decoded == frame)
}

@Test func configurationSyncStateAppliesDifferentSnapshotsOnly() {
    var state = ConfigurationSyncState(configuration: .defaults)

    #expect(state.applyLocal(.defaults, sourceDeviceId: "ios-1", updatedAtNanos: 10) == nil)

    let changed = TrackpadConfiguration.defaults.withPointerSpeedMultiplier(3)
    let localSnapshot = state.applyLocal(changed, sourceDeviceId: "ios-1", updatedAtNanos: 11)

    #expect(localSnapshot?.revision == 1)
    #expect(localSnapshot?.configuration == changed)
    #expect(state.configuration == changed)

    let unchangedRemote = ConfigurationSyncSnapshot(
        revision: 2,
        updatedAtNanos: 12,
        sourceDeviceId: "mac-1",
        configuration: changed
    )
    #expect(state.applyRemote(unchangedRemote) == .unchanged)

    let remoteConfiguration = changed.withScrollMomentumAmount(1.8)
    let remoteSnapshot = ConfigurationSyncSnapshot(
        revision: 3,
        updatedAtNanos: 13,
        sourceDeviceId: "mac-1",
        configuration: remoteConfiguration
    )
    #expect(state.applyRemote(remoteSnapshot) == .applied)
    #expect(state.configuration == remoteConfiguration)
}
