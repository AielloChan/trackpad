public struct TrackpadConfiguration: Codable, Equatable, Sendable {
    public let pointer: PointerConfiguration
    public let gestures: GestureConfiguration
    public let scrollMomentum: ScrollMomentumSettings

    public init(
        pointer: PointerConfiguration,
        gestures: GestureConfiguration,
        scrollMomentum: ScrollMomentumSettings
    ) {
        self.pointer = pointer
        self.gestures = gestures
        self.scrollMomentum = scrollMomentum
    }

    public static let defaults = TrackpadConfiguration(
        pointer: PointerConfiguration(speedMultiplier: 2.1),
        gestures: GestureConfiguration(
            tapMaximumDurationMilliseconds: 250,
            tapDragMaximumIntervalMilliseconds: 140,
            scrollReleaseTapSuppressionMilliseconds: 80
        ),
        scrollMomentum: ScrollMomentumSettings(
            amount: 5,
            decayRate: 0.95,
            tailWindowMilliseconds: 140
        )
    )

    public func withPointerSpeedMultiplier(_ speedMultiplier: Double) -> TrackpadConfiguration {
        TrackpadConfiguration(
            pointer: PointerConfiguration(speedMultiplier: speedMultiplier),
            gestures: gestures,
            scrollMomentum: scrollMomentum
        )
    }

    public func withScrollMomentumAmount(_ amount: Double) -> TrackpadConfiguration {
        TrackpadConfiguration(
            pointer: pointer,
            gestures: gestures,
            scrollMomentum: ScrollMomentumSettings(
                amount: amount,
                decayRate: scrollMomentum.decayRate,
                tailWindowMilliseconds: scrollMomentum.tailWindowMilliseconds
            )
        )
    }

    public func withGestures(_ gestures: GestureConfiguration) -> TrackpadConfiguration {
        TrackpadConfiguration(
            pointer: pointer,
            gestures: gestures,
            scrollMomentum: scrollMomentum
        )
    }

    public func withScrollMomentum(_ scrollMomentum: ScrollMomentumSettings) -> TrackpadConfiguration {
        TrackpadConfiguration(
            pointer: pointer,
            gestures: gestures,
            scrollMomentum: scrollMomentum
        )
    }
}

public enum TrackpadConfigurationLimits {
    public static let pointerSpeedMultiplier: ClosedRange<Double> = 0.2...10
    public static let scrollMomentumAmount: ClosedRange<Double> = 0...12
    public static let scrollMomentumDecayRate: ClosedRange<Double> = 0.72...0.995
    public static let scrollMomentumTailWindowMilliseconds: ClosedRange<Double> = 30...500
    public static let tapMaximumDurationMilliseconds: ClosedRange<Double> = 60...500
    public static let tapDragMaximumIntervalMilliseconds: ClosedRange<Double> = 40...250
    public static let scrollReleaseTapSuppressionMilliseconds: ClosedRange<Double> = 0...250
}

public struct PointerConfiguration: Codable, Equatable, Sendable {
    public let speedMultiplier: Double

    public init(speedMultiplier: Double) {
        self.speedMultiplier = speedMultiplier
    }
}

public struct GestureConfiguration: Codable, Equatable, Sendable {
    public let tapMaximumDurationMilliseconds: Double
    public let tapDragMaximumIntervalMilliseconds: Double
    public let scrollReleaseTapSuppressionMilliseconds: Double

    public init(
        tapMaximumDurationMilliseconds: Double,
        tapDragMaximumIntervalMilliseconds: Double,
        scrollReleaseTapSuppressionMilliseconds: Double
    ) {
        self.tapMaximumDurationMilliseconds = tapMaximumDurationMilliseconds
        self.tapDragMaximumIntervalMilliseconds = tapDragMaximumIntervalMilliseconds
        self.scrollReleaseTapSuppressionMilliseconds = scrollReleaseTapSuppressionMilliseconds
    }
}

public struct ConfigurationSyncSnapshot: Codable, Equatable, Sendable {
    public let revision: UInt64
    public let updatedAtNanos: UInt64
    public let sourceDeviceId: String
    public let configuration: TrackpadConfiguration

    public init(
        revision: UInt64,
        updatedAtNanos: UInt64,
        sourceDeviceId: String,
        configuration: TrackpadConfiguration
    ) {
        self.revision = revision
        self.updatedAtNanos = updatedAtNanos
        self.sourceDeviceId = sourceDeviceId
        self.configuration = configuration
    }
}

public enum ConfigurationSyncApplyResult: Equatable, Sendable {
    case applied
    case unchanged
}

public struct ConfigurationSyncState: Equatable, Sendable {
    public private(set) var configuration: TrackpadConfiguration
    public private(set) var revision: UInt64

    public init(configuration: TrackpadConfiguration, revision: UInt64 = 0) {
        self.configuration = configuration
        self.revision = revision
    }

    public mutating func applyLocal(
        _ configuration: TrackpadConfiguration,
        sourceDeviceId: String,
        updatedAtNanos: UInt64
    ) -> ConfigurationSyncSnapshot? {
        guard self.configuration != configuration else {
            return nil
        }

        revision += 1
        self.configuration = configuration
        return ConfigurationSyncSnapshot(
            revision: revision,
            updatedAtNanos: updatedAtNanos,
            sourceDeviceId: sourceDeviceId,
            configuration: configuration
        )
    }

    public func snapshot(sourceDeviceId: String, updatedAtNanos: UInt64) -> ConfigurationSyncSnapshot {
        ConfigurationSyncSnapshot(
            revision: revision,
            updatedAtNanos: updatedAtNanos,
            sourceDeviceId: sourceDeviceId,
            configuration: configuration
        )
    }

    public mutating func applyRemote(_ snapshot: ConfigurationSyncSnapshot) -> ConfigurationSyncApplyResult {
        guard configuration != snapshot.configuration else {
            return .unchanged
        }

        configuration = snapshot.configuration
        revision = max(revision, snapshot.revision)
        return .applied
    }
}
