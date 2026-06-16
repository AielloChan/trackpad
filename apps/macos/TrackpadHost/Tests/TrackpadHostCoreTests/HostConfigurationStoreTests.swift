import Foundation
import Testing
import TrackpadKit
@testable import TrackpadHostCore

@Test func hostConfigurationStoreReturnsNilWhenFileIsMissing() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = HostConfigurationStore(fileURL: directory.appendingPathComponent("host_configuration.json"))

    let loaded = try store.load()

    #expect(loaded == nil)
}

@Test func hostConfigurationStorePersistsPrettyPrintedJSONConfiguration() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileURL = directory.appendingPathComponent("host_configuration.json")
    let store = HostConfigurationStore(fileURL: fileURL)
    let configuration = TrackpadConfiguration.defaults.withScrollMomentum(
        ScrollMomentumSettings(
            isEnabled: true,
            amount: 5,
            decayRate: 0.945,
            tailWindowMilliseconds: 140
        )
    )

    try store.save(configuration, savedAtNanos: 123)
    let persisted = try store.load()
    let loaded = try #require(persisted)
    let content = try String(contentsOf: fileURL, encoding: .utf8)

    #expect(loaded.schemaVersion == 1)
    #expect(loaded.savedAtNanos == 123)
    #expect(loaded.configuration == configuration)
    #expect(content.contains("\"schemaVersion\" : 1"))
    #expect(content.contains("\"decayRate\" : 0.945"))
}
