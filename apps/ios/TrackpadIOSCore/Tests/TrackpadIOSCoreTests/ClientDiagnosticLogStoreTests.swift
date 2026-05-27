import Foundation
import Testing
@testable import TrackpadIOSCore

@Test func clientDiagnosticLogStoreAppendsAndBuildsUpload() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let logURL = directory.appendingPathComponent("client.log")
    let store = ClientDiagnosticLogStore(fileURL: logURL, maximumUploadBytes: 1_000)

    store.append("######### ios.client first")
    store.append("######### ios.touch second")

    let upload = try store.makeUpload(
        requestId: "request-1",
        deviceId: "ios-1",
        deviceName: "iPad",
        createdAtNanos: 2_000
    )

    #expect(upload.requestId == "request-1")
    #expect(upload.deviceId == "ios-1")
    #expect(upload.deviceName == "iPad")
    #expect(upload.content.contains("######### ios.client first"))
    #expect(upload.content.contains("######### ios.touch second"))
    #expect(upload.truncated == false)
}

@Test func clientDiagnosticLogStoreTruncatesUploadFromEnd() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let logURL = directory.appendingPathComponent("client.log")
    let store = ClientDiagnosticLogStore(fileURL: logURL, maximumUploadBytes: 32)

    store.append("old-line-should-drop")
    store.append("new-line-should-remain")

    let upload = try store.makeUpload(
        requestId: "request-1",
        deviceId: "ios-1",
        deviceName: "iPad",
        createdAtNanos: 2_000
    )

    #expect(upload.content.contains("new-line-should-remain"))
    #expect(upload.content.contains("old-line-should-drop") == false)
    #expect(upload.truncated)
}
