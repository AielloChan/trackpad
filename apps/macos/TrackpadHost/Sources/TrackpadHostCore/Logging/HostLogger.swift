import Foundation

public enum HostLogLevel: String, Sendable {
    case debug
    case info
    case warning
    case error
}

public protocol HostLogging: Sendable {
    func log(level: HostLogLevel, category: String, message: String)
}

public extension HostLogging {
    func debug(category: String, _ message: String) {
        log(level: .debug, category: category, message: message)
    }

    func info(category: String, _ message: String) {
        log(level: .info, category: category, message: message)
    }

    func warning(category: String, _ message: String) {
        log(level: .warning, category: category, message: message)
    }

    func error(category: String, _ message: String) {
        log(level: .error, category: category, message: message)
    }
}

public struct DisabledHostLogger: HostLogging {
    public init() {}

    public func log(level: HostLogLevel, category: String, message: String) {}
}

public final class FileHostLogger: HostLogging, @unchecked Sendable {
    public static let defaultFileURL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/Trackpad/host.log")

    public let fileURL: URL

    private let maximumFileSizeBytes: UInt64
    private let lock = NSLock()

    public init(
        fileURL: URL = FileHostLogger.defaultFileURL,
        maximumFileSizeBytes: UInt64 = 2_000_000
    ) {
        self.fileURL = fileURL
        self.maximumFileSizeBytes = maximumFileSizeBytes
    }

    public func log(level: HostLogLevel, category: String, message: String) {
        lock.lock()
        defer {
            lock.unlock()
        }

        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try rotateIfNeeded()
            let line = "\(Self.timestamp()) [\(level.rawValue)] [\(category)] \(message)\n"
            let data = Data(line.utf8)
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
            // Logging must never break input handling.
        }
    }

    private func rotateIfNeeded() throws {
        guard maximumFileSizeBytes > 0,
              let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attributes[.size] as? UInt64,
              size >= maximumFileSizeBytes else {
            return
        }

        let rotatedURL = fileURL.deletingPathExtension().appendingPathExtension("log.1")
        if FileManager.default.fileExists(atPath: rotatedURL.path) {
            try FileManager.default.removeItem(at: rotatedURL)
        }
        try FileManager.default.moveItem(at: fileURL, to: rotatedURL)
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
