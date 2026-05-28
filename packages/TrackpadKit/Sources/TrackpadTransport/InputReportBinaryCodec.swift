import Foundation
#if SWIFT_PACKAGE
import TrackpadProtocol
#endif

public enum InputReportBinaryCodec {
    public static let magicByte: UInt8 = 0xA7
    public static let frameLength = 32

    private static let version: UInt8 = 1
    private static let fixedPointScale = 256.0

    public static func encode(_ report: InputReport) throws -> Data {
        var data = Data()
        data.reserveCapacity(frameLength)
        data.append(magicByte)
        data.append(version)

        switch report.kind {
        case .pointerMove(let dx, let dy):
            data.append(1)
            data.append(0)
            appendCommonFields(report, to: &data)
            appendFixedPoint(dx, to: &data)
            appendFixedPoint(dy, to: &data)
            data.append(0)
            data.append(0)
            data.append(0)
            data.append(0)
        case .pointerButton(let button, let phase):
            data.append(2)
            data.append(0)
            appendCommonFields(report, to: &data)
            appendFixedPoint(0, to: &data)
            appendFixedPoint(0, to: &data)
            data.append(button.reportRawValue)
            data.append(phase.reportRawValue)
            data.append(0)
            data.append(0)
        case .tap(let button):
            data.append(3)
            data.append(0)
            appendCommonFields(report, to: &data)
            appendFixedPoint(0, to: &data)
            appendFixedPoint(0, to: &data)
            data.append(button.reportRawValue)
            data.append(0)
            data.append(0)
            data.append(0)
        case .scroll(let dx, let dy, let phase, let momentumPhase):
            data.append(4)
            data.append(0)
            appendCommonFields(report, to: &data)
            appendFixedPoint(dx, to: &data)
            appendFixedPoint(dy, to: &data)
            data.append(0)
            data.append(phase.reportRawValue)
            data.append(momentumPhase?.reportRawValue ?? 0)
            data.append(0)
        case .systemAction(let action):
            data.append(5)
            data.append(0)
            appendCommonFields(report, to: &data)
            appendFixedPoint(0, to: &data)
            appendFixedPoint(0, to: &data)
            data.append(action.reportRawValue)
            data.append(0)
            data.append(0)
            data.append(0)
        case .contact(let phase, let contactCount):
            data.append(6)
            data.append(0)
            appendCommonFields(report, to: &data)
            appendFixedPoint(0, to: &data)
            appendFixedPoint(0, to: &data)
            data.append(clampedUInt8(contactCount))
            data.append(phase.reportRawValue)
            data.append(0)
            data.append(0)
        }

        return data
    }

    public static func decode<Bytes: DataProtocol>(_ bytes: Bytes) throws -> InputReport {
        let data = Data(bytes)
        guard data.count == frameLength else {
            throw InputReportBinaryCodecError.invalidLength(data.count)
        }
        guard data[0] == magicByte else {
            throw InputReportBinaryCodecError.invalidMagic(data[0])
        }
        guard data[1] == version else {
            throw InputReportBinaryCodecError.unsupportedVersion(data[1])
        }

        let sequenceNumber = readUInt64(from: data, at: 4)
        let timestampNanos = readUInt64(from: data, at: 12)
        let dx = readFixedPoint(from: data, at: 20)
        let dy = readFixedPoint(from: data, at: 24)
        let buttonRaw = data[28]
        let phaseRaw = data[29]
        let momentumRaw = data[30]

        switch data[2] {
        case 1:
            return InputReport(
                sequenceNumber: sequenceNumber,
                timestampNanos: timestampNanos,
                kind: .pointerMove(dx: dx, dy: dy)
            )
        case 2:
            return InputReport(
                sequenceNumber: sequenceNumber,
                timestampNanos: timestampNanos,
                kind: .pointerButton(
                    button: try PointerButton(reportRawValue: buttonRaw),
                    phase: try ButtonPhase(reportRawValue: phaseRaw)
                )
            )
        case 3:
            return InputReport(
                sequenceNumber: sequenceNumber,
                timestampNanos: timestampNanos,
                kind: .tap(button: try PointerButton(reportRawValue: buttonRaw))
            )
        case 4:
            return InputReport(
                sequenceNumber: sequenceNumber,
                timestampNanos: timestampNanos,
                kind: .scroll(
                    dx: dx,
                    dy: dy,
                    phase: try ScrollPhase(reportRawValue: phaseRaw),
                    momentumPhase: try ScrollPhase(optionalReportRawValue: momentumRaw)
                )
            )
        case 5:
            return InputReport(
                sequenceNumber: sequenceNumber,
                timestampNanos: timestampNanos,
                kind: .systemAction(action: try SystemAction(reportRawValue: buttonRaw))
            )
        case 6:
            return InputReport(
                sequenceNumber: sequenceNumber,
                timestampNanos: timestampNanos,
                kind: .contact(
                    phase: try ContactPhase(reportRawValue: phaseRaw),
                    contactCount: Int(buttonRaw)
                )
            )
        default:
            throw InputReportBinaryCodecError.unsupportedKind(data[2])
        }
    }

    private static func appendCommonFields(_ report: InputReport, to data: inout Data) {
        append(report.sequenceNumber, to: &data)
        append(report.timestampNanos, to: &data)
    }

    private static func appendFixedPoint(_ value: Double, to data: inout Data) {
        let scaled = (value * fixedPointScale).rounded()
        let clamped = min(max(scaled, Double(Int32.min)), Double(Int32.max))
        append(Int32(clamped), to: &data)
    }

    private static func clampedUInt8(_ value: Int) -> UInt8 {
        UInt8(min(max(value, 0), Int(UInt8.max)))
    }

    private static func readFixedPoint(from data: Data, at index: Int) -> Double {
        Double(readInt32(from: data, at: index)) / fixedPointScale
    }

    private static func append(_ value: UInt64, to data: inout Data) {
        var bigEndian = value.bigEndian
        withUnsafeBytes(of: &bigEndian) { data.append(contentsOf: $0) }
    }

    private static func append(_ value: Int32, to data: inout Data) {
        var bigEndian = value.bigEndian
        withUnsafeBytes(of: &bigEndian) { data.append(contentsOf: $0) }
    }

    private static func readUInt64(from data: Data, at index: Int) -> UInt64 {
        data[index..<(index + 8)].reduce(UInt64(0)) { result, byte in
            (result << 8) | UInt64(byte)
        }
    }

    private static func readInt32(from data: Data, at index: Int) -> Int32 {
        let unsigned = data[index..<(index + 4)].reduce(UInt32(0)) { result, byte in
            (result << 8) | UInt32(byte)
        }
        return Int32(bitPattern: unsigned)
    }
}

public enum InputReportBinaryCodecError: Error, Equatable {
    case invalidLength(Int)
    case invalidMagic(UInt8)
    case unsupportedVersion(UInt8)
    case unsupportedKind(UInt8)
    case unsupportedButton(UInt8)
    case unsupportedButtonPhase(UInt8)
    case unsupportedScrollPhase(UInt8)
    case unsupportedSystemAction(UInt8)
    case unsupportedContactPhase(UInt8)
}

private extension PointerButton {
    var reportRawValue: UInt8 {
        switch self {
        case .left: return 1
        case .right: return 2
        case .middle: return 3
        }
    }

    init(reportRawValue: UInt8) throws {
        switch reportRawValue {
        case 1: self = .left
        case 2: self = .right
        case 3: self = .middle
        default: throw InputReportBinaryCodecError.unsupportedButton(reportRawValue)
        }
    }
}

private extension ButtonPhase {
    var reportRawValue: UInt8 {
        switch self {
        case .down: return 1
        case .up: return 2
        }
    }

    init(reportRawValue: UInt8) throws {
        switch reportRawValue {
        case 1: self = .down
        case 2: self = .up
        default: throw InputReportBinaryCodecError.unsupportedButtonPhase(reportRawValue)
        }
    }
}

private extension ScrollPhase {
    var reportRawValue: UInt8 {
        switch self {
        case .began: return 1
        case .changed: return 2
        case .ended: return 3
        }
    }

    init(reportRawValue: UInt8) throws {
        switch reportRawValue {
        case 1: self = .began
        case 2: self = .changed
        case 3: self = .ended
        default: throw InputReportBinaryCodecError.unsupportedScrollPhase(reportRawValue)
        }
    }

    init?(optionalReportRawValue: UInt8) throws {
        switch optionalReportRawValue {
        case 0: return nil
        case 1: self = .began
        case 2: self = .changed
        case 3: self = .ended
        default: throw InputReportBinaryCodecError.unsupportedScrollPhase(optionalReportRawValue)
        }
    }
}

private extension SystemAction {
    var reportRawValue: UInt8 {
        switch self {
        case .missionControl: return 1
        case .appExpose: return 2
        case .previousSpace: return 3
        case .nextSpace: return 4
        }
    }

    init(reportRawValue: UInt8) throws {
        switch reportRawValue {
        case 1: self = .missionControl
        case 2: self = .appExpose
        case 3: self = .previousSpace
        case 4: self = .nextSpace
        default: throw InputReportBinaryCodecError.unsupportedSystemAction(reportRawValue)
        }
    }
}

private extension ContactPhase {
    var reportRawValue: UInt8 {
        switch self {
        case .began: return 1
        }
    }

    init(reportRawValue: UInt8) throws {
        switch reportRawValue {
        case 1: self = .began
        default: throw InputReportBinaryCodecError.unsupportedContactPhase(reportRawValue)
        }
    }
}
