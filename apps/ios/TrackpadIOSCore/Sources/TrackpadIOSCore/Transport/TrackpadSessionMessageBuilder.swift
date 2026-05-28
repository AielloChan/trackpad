import Foundation
#if SWIFT_PACKAGE
import TrackpadKit
#endif

public enum TrackpadSessionMessageBuilder {
    public static func clientHelloData(for configuration: TrackpadConnectionConfiguration) throws -> Data {
        try SessionFrameLineCodec.encode(
            .clientHello(
                ClientHello(
                    protocolVersion: 1,
                    deviceId: configuration.deviceId,
                    deviceName: configuration.deviceName,
                    pairingCode: configuration.pairingCode,
                    trustedClientKey: configuration.trustedClientKey
                )
            )
        )
    }

    public static func inputData(for event: InputEvent) throws -> Data {
        try InputReportBinaryCodec.encode(InputReport(event: event))
    }

    public static func pingData(for ping: SessionPing) throws -> Data {
        try SessionFrameLineCodec.encode(.ping(ping))
    }

    public static func clientLogUploadData(for upload: ClientLogUpload) throws -> Data {
        try SessionFrameLineCodec.encode(.clientLogUpload(upload))
    }

    public static func scrollMomentumSettingsData(for settings: ScrollMomentumSettings) throws -> Data {
        try SessionFrameLineCodec.encode(.scrollMomentumSettings(settings))
    }

    public static func configurationSyncData(for snapshot: ConfigurationSyncSnapshot) throws -> Data {
        try SessionFrameLineCodec.encode(.configurationSync(snapshot))
    }
}
