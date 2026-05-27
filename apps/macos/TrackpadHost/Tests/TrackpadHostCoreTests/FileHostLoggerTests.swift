import Foundation
import Testing
@testable import TrackpadHostCore

@Test func fileHostLoggerWritesDiagnosticLinesToChosenFile() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let logURL = directory.appendingPathComponent("host.log")
    let logger = FileHostLogger(fileURL: logURL)

    logger.info(category: "test", "first line")
    logger.error(category: "test", "second line")

    let contents = try String(contentsOf: logURL, encoding: .utf8)
    #expect(contents.contains("[info] [test] first line"))
    #expect(contents.contains("[error] [test] second line"))
}
