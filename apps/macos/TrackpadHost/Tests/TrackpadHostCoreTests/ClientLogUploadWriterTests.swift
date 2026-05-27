import Foundation
import Testing
import TrackpadKit
@testable import TrackpadHostCore

@Test func clientLogUploadWriterPersistsUploadedContent() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let writer = ClientLogUploadWriter(directoryURL: directory)
    let upload = ClientLogUpload(
        requestId: "request-1",
        deviceId: "ios/device:1",
        deviceName: "Aiello iPad",
        createdAtNanos: 2_000,
        content: "######### ios.client example",
        truncated: false
    )

    let url = try writer.write(upload)
    let content = try String(contentsOf: url, encoding: .utf8)

    #expect(url.lastPathComponent.contains("ios-device-1"))
    #expect(content.contains("requestId=request-1"))
    #expect(content.contains("deviceName=Aiello iPad"))
    #expect(content.contains("######### ios.client example"))
}
