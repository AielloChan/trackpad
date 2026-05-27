import Foundation
import TrackpadKit

public final class ClientLogUploadWriter: @unchecked Sendable {
    public static let defaultDirectoryURL = FileHostLogger.defaultFileURL
        .deletingLastPathComponent()
        .appendingPathComponent("client-logs", isDirectory: true)

    private let directoryURL: URL
    private let lock = NSLock()

    public init(directoryURL: URL = ClientLogUploadWriter.defaultDirectoryURL) {
        self.directoryURL = directoryURL
    }

    public func write(_ upload: ClientLogUpload) throws -> URL {
        lock.lock()
        defer {
            lock.unlock()
        }

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let fileName = "\(sanitize(upload.deviceId))-\(sanitize(upload.requestId)).log"
        let url = directoryURL.appendingPathComponent(fileName)
        let content = """
        requestId=\(upload.requestId)
        deviceId=\(upload.deviceId)
        deviceName=\(upload.deviceName)
        createdAtNanos=\(upload.createdAtNanos)
        truncated=\(upload.truncated)

        \(upload.content)
        """
        try Data(content.utf8).write(to: url, options: .atomic)
        return url
    }

    private func sanitize(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let result = String(scalars)
        return result.isEmpty ? "unknown" : result
    }
}
