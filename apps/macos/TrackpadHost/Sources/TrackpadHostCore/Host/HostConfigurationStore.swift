import Foundation
import TrackpadKit

public struct PersistedHostConfiguration: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let savedAtNanos: UInt64
    public let configuration: TrackpadConfiguration

    public init(
        schemaVersion: Int = 1,
        savedAtNanos: UInt64,
        configuration: TrackpadConfiguration
    ) {
        self.schemaVersion = schemaVersion
        self.savedAtNanos = savedAtNanos
        self.configuration = configuration
    }
}

public final class HostConfigurationStore: @unchecked Sendable {
    public static let defaultFileURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Trackpad", isDirectory: true)
        .appendingPathComponent("host_configuration.json")

    public let fileURL: URL

    private let lock = NSLock()
    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()

    public init(fileURL: URL = HostConfigurationStore.defaultFileURL) {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func load() throws -> PersistedHostConfiguration? {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(PersistedHostConfiguration.self, from: data)
    }

    public func save(
        _ configuration: TrackpadConfiguration,
        savedAtNanos: UInt64
    ) throws {
        lock.lock()
        defer {
            lock.unlock()
        }

        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let persisted = PersistedHostConfiguration(
            savedAtNanos: savedAtNanos,
            configuration: configuration
        )
        let data = try encoder.encode(persisted)
        try data.write(to: fileURL, options: .atomic)
    }
}
