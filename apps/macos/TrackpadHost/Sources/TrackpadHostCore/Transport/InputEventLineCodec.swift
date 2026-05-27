import Foundation
import TrackpadKit

public struct SessionFrameLineCodec: Sendable {
    private var buffer = Data()
    private let decoder = JSONDecoder()

    public init() {}

    public static func encode(_ frame: SessionFrame) throws -> Data {
        var data = try JSONEncoder().encode(frame)
        data.append(UInt8(ascii: "\n"))
        return data
    }

    public mutating func append<Chunk: DataProtocol>(_ data: Chunk) throws -> [SessionFrame] {
        buffer.append(contentsOf: data)
        return try decodeAvailableLines()
    }

    private mutating func decodeAvailableLines() throws -> [SessionFrame] {
        var frames: [SessionFrame] = []

        while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let line = buffer[..<newlineIndex]
            buffer.removeSubrange(...newlineIndex)

            guard !line.isEmpty else {
                continue
            }

            frames.append(try decoder.decode(SessionFrame.self, from: Data(line)))
        }

        return frames
    }
}

public typealias InputEventLineCodec = SessionFrameLineCodec
