import Foundation
#if SWIFT_PACKAGE
import TrackpadKit
#endif

public final class ClientDiagnosticLogStore: @unchecked Sendable {
    public static let defaultFileURL = FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Trackpad/client.log")

    private let fileURL: URL
    private let maximumUploadBytes: Int
    private let lock = NSLock()

    public init(
        fileURL: URL = ClientDiagnosticLogStore.defaultFileURL,
        maximumUploadBytes: Int = 48_000
    ) {
        self.fileURL = fileURL
        self.maximumUploadBytes = maximumUploadBytes
    }

    public func append(_ message: String) {
        lock.lock()
        defer {
            lock.unlock()
        }

        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = Data((message + "\n").utf8)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let handle = try FileHandle(forWritingTo: fileURL)
                defer {
                    try? handle.close()
                }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } else {
                try data.write(to: fileURL, options: .atomic)
            }
        } catch {
            // Client diagnostics must never affect input handling.
        }
    }

    public func makeUpload(
        requestId: String,
        deviceId: String,
        deviceName: String,
        createdAtNanos: UInt64
    ) throws -> ClientLogUpload {
        lock.lock()
        defer {
            lock.unlock()
        }

        let data = (try? Data(contentsOf: fileURL)) ?? Data()
        let truncated = data.count > maximumUploadBytes
        let uploadData = truncated ? data.suffix(maximumUploadBytes) : data[...]
        return ClientLogUpload(
            requestId: requestId,
            deviceId: deviceId,
            deviceName: deviceName,
            createdAtNanos: createdAtNanos,
            content: String(decoding: uploadData, as: UTF8.self),
            truncated: truncated
        )
    }
}
