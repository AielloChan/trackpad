import Foundation
#if SWIFT_PACKAGE
import TrackpadProtocol
#endif

public enum SessionStreamMessage: Equatable, Sendable {
    case frame(SessionFrame)
    case input(InputEvent)
}

public struct SessionStreamCodec: Sendable {
    private var buffer = Data()
    private let decoder = JSONDecoder()

    public init() {}

    public mutating func append<Chunk: DataProtocol>(_ data: Chunk) throws -> [SessionStreamMessage] {
        buffer.append(contentsOf: data)

        var messages: [SessionStreamMessage] = []
        while !buffer.isEmpty {
            if buffer.first == InputReportBinaryCodec.magicByte {
                guard buffer.count >= InputReportBinaryCodec.frameLength else {
                    break
                }

                let reportData = buffer.prefix(InputReportBinaryCodec.frameLength)
                buffer.removeSubrange(..<InputReportBinaryCodec.frameLength)
                let report = try InputReportBinaryCodec.decode(reportData)
                messages.append(.input(report.inputEvent))
                continue
            }

            guard let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) else {
                break
            }

            let line = buffer[..<newlineIndex]
            buffer.removeSubrange(...newlineIndex)
            guard !line.isEmpty else {
                continue
            }

            messages.append(.frame(try decoder.decode(SessionFrame.self, from: Data(line))))
        }

        return messages
    }
}
