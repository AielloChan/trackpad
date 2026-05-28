import CryptoKit
import Foundation
import TrackpadKit

public struct AuthorizedClientRecord: Codable, Equatable, Sendable {
    public let id: String
    public let deviceId: String
    public let deviceName: String
    public let clientKeyHash: String
    public let firstAuthorizedAtNanos: UInt64
    public let lastAuthorizedAtNanos: UInt64
    public let firstRemoteAddress: String?
    public let lastRemoteAddress: String?

    public init(
        id: String,
        deviceId: String,
        deviceName: String,
        clientKeyHash: String,
        firstAuthorizedAtNanos: UInt64,
        lastAuthorizedAtNanos: UInt64,
        firstRemoteAddress: String?,
        lastRemoteAddress: String?
    ) {
        self.id = id
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.clientKeyHash = clientKeyHash
        self.firstAuthorizedAtNanos = firstAuthorizedAtNanos
        self.lastAuthorizedAtNanos = lastAuthorizedAtNanos
        self.firstRemoteAddress = firstRemoteAddress
        self.lastRemoteAddress = lastRemoteAddress
    }
}

public final class AuthorizedClientStore: @unchecked Sendable {
    public static let defaultFileURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Trackpad", isDirectory: true)
        .appendingPathComponent("authorized_clients.jsonl")

    private let fileURL: URL
    private let lock = NSLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(fileURL: URL = AuthorizedClientStore.defaultFileURL) {
        self.fileURL = fileURL
    }

    public func authorize(
        _ hello: ClientHello,
        remoteAddress: String?,
        timestampNanos: UInt64
    ) throws -> TrustedClientKey {
        lock.lock()
        defer {
            lock.unlock()
        }

        var records = try loadRecordsLocked()
        let clientKey = Self.generateClientKey()
        let existing = records[hello.deviceId]
        let record = AuthorizedClientRecord(
            id: hello.deviceId,
            deviceId: hello.deviceId,
            deviceName: hello.deviceName,
            clientKeyHash: Self.hash(clientKey),
            firstAuthorizedAtNanos: existing?.firstAuthorizedAtNanos ?? timestampNanos,
            lastAuthorizedAtNanos: timestampNanos,
            firstRemoteAddress: existing?.firstRemoteAddress ?? remoteAddress,
            lastRemoteAddress: remoteAddress
        )

        records[hello.deviceId] = record
        try writeRecordsLocked(records)
        return TrustedClientKey(
            deviceId: hello.deviceId,
            clientKey: clientKey,
            issuedAtNanos: timestampNanos
        )
    }

    public func validate(
        _ hello: ClientHello,
        remoteAddress: String?,
        timestampNanos: UInt64
    ) throws -> Bool {
        guard let trustedClientKey = hello.trustedClientKey, !trustedClientKey.isEmpty else {
            return false
        }

        lock.lock()
        defer {
            lock.unlock()
        }

        var records = try loadRecordsLocked()
        guard let record = records[hello.deviceId],
              record.clientKeyHash == Self.hash(trustedClientKey) else {
            return false
        }

        records[hello.deviceId] = AuthorizedClientRecord(
            id: record.id,
            deviceId: record.deviceId,
            deviceName: hello.deviceName,
            clientKeyHash: record.clientKeyHash,
            firstAuthorizedAtNanos: record.firstAuthorizedAtNanos,
            lastAuthorizedAtNanos: timestampNanos,
            firstRemoteAddress: record.firstRemoteAddress,
            lastRemoteAddress: remoteAddress
        )
        try writeRecordsLocked(records)
        return true
    }

    private func loadRecordsLocked() throws -> [String: AuthorizedClientRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return [:]
        }

        let content = try String(contentsOf: fileURL, encoding: .utf8)
        var records: [String: AuthorizedClientRecord] = [:]
        for line in content.split(separator: "\n") {
            let record = try decoder.decode(AuthorizedClientRecord.self, from: Data(line.utf8))
            records[record.deviceId] = record
        }
        return records
    }

    private func writeRecordsLocked(_ records: [String: AuthorizedClientRecord]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let lines = try records.values
            .sorted { $0.deviceId < $1.deviceId }
            .map { record in
                String(decoding: try encoder.encode(record), as: UTF8.self)
            }
            .joined(separator: "\n")
        let content = lines.isEmpty ? "" : lines + "\n"
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private static func generateClientKey() -> String {
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        return Data(bytes).base64EncodedString()
    }

    private static func hash(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
