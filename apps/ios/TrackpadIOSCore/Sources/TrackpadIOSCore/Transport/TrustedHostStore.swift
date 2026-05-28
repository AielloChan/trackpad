import Foundation
#if SWIFT_PACKAGE
import TrackpadKit
#endif

public struct TrustedHostRecord: Codable, Equatable, Sendable {
    public let id: String
    public let hostIdentity: String
    public let host: String
    public let port: UInt16
    public let deviceId: String
    public let clientKey: String
    public let firstAuthorizedAtNanos: UInt64
    public let lastUsedAtNanos: UInt64

    public init(
        id: String,
        hostIdentity: String,
        host: String,
        port: UInt16,
        deviceId: String,
        clientKey: String,
        firstAuthorizedAtNanos: UInt64,
        lastUsedAtNanos: UInt64
    ) {
        self.id = id
        self.hostIdentity = hostIdentity
        self.host = host
        self.port = port
        self.deviceId = deviceId
        self.clientKey = clientKey
        self.firstAuthorizedAtNanos = firstAuthorizedAtNanos
        self.lastUsedAtNanos = lastUsedAtNanos
    }
}

public final class TrustedHostStore: @unchecked Sendable {
    public static let defaultFileURL: URL = {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseURL
            .appendingPathComponent("Trackpad", isDirectory: true)
            .appendingPathComponent("trusted_hosts.jsonl")
    }()

    private let fileURL: URL
    private let lock = NSLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(fileURL: URL = TrustedHostStore.defaultFileURL) {
        self.fileURL = fileURL
    }

    public func clientKey(
        for configuration: TrackpadConnectionConfiguration,
        timestampNanos: UInt64
    ) throws -> String? {
        lock.lock()
        defer {
            lock.unlock()
        }

        var records = try loadRecordsLocked()
        guard let record = records[configuration.trustedHostIdentity]
            ?? legacySingleManualRecord(for: configuration, in: records) else {
            return nil
        }

        records[configuration.trustedHostIdentity] = TrustedHostRecord(
            id: configuration.trustedHostIdentity,
            hostIdentity: configuration.trustedHostIdentity,
            host: configuration.host,
            port: configuration.port,
            deviceId: record.deviceId,
            clientKey: record.clientKey,
            firstAuthorizedAtNanos: record.firstAuthorizedAtNanos,
            lastUsedAtNanos: timestampNanos
        )
        try writeRecordsLocked(records)
        return record.clientKey
    }

    public func save(
        _ key: TrustedClientKey,
        for configuration: TrackpadConnectionConfiguration,
        timestampNanos: UInt64
    ) throws {
        lock.lock()
        defer {
            lock.unlock()
        }

        var records = try loadRecordsLocked()
        for hostIdentity in configuration.trustedHostIdentities {
            let existing = records[hostIdentity]
            records[hostIdentity] = TrustedHostRecord(
                id: hostIdentity,
                hostIdentity: hostIdentity,
                host: configuration.host,
                port: configuration.port,
                deviceId: key.deviceId,
                clientKey: key.clientKey,
                firstAuthorizedAtNanos: existing?.firstAuthorizedAtNanos ?? key.issuedAtNanos,
                lastUsedAtNanos: timestampNanos
            )
        }
        try writeRecordsLocked(records)
    }

    private func loadRecordsLocked() throws -> [String: TrustedHostRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return [:]
        }

        let content = try String(contentsOf: fileURL, encoding: .utf8)
        var records: [String: TrustedHostRecord] = [:]
        for line in content.split(separator: "\n") {
            let record = try decoder.decode(TrustedHostRecord.self, from: Data(line.utf8))
            records[record.hostIdentity] = record
        }
        return records
    }

    private func writeRecordsLocked(_ records: [String: TrustedHostRecord]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let lines = try records.values
            .sorted { $0.hostIdentity < $1.hostIdentity }
            .map { record in
                String(decoding: try encoder.encode(record), as: UTF8.self)
            }
            .joined(separator: "\n")
        let content = lines.isEmpty ? "" : lines + "\n"
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private func legacySingleManualRecord(
        for configuration: TrackpadConnectionConfiguration,
        in records: [String: TrustedHostRecord]
    ) -> TrustedHostRecord? {
        guard configuration.trustedHostIdentity.hasPrefix("bonjour:") else {
            return nil
        }

        let manualRecords = records.values.filter { !$0.hostIdentity.hasPrefix("bonjour:") }
        guard manualRecords.count == 1 else {
            return nil
        }

        return manualRecords[0]
    }
}
