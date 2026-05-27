import Testing
@testable import TrackpadIOSCore

@Test func networkPathSnapshotSortsInterfacesByPreference() {
    let snapshot = NetworkPathSnapshot(
        status: .satisfied,
        interfaceKinds: [.cellular, .wifi, .wiredEthernet, .wifi]
    )

    #expect(snapshot.interfaceKinds == [.wiredEthernet, .wifi, .cellular])
    #expect(snapshot.preferredInterfaceKind == .wiredEthernet)
}

@Test func networkPathSnapshotMarksWiredAsCableCandidate() {
    let snapshot = NetworkPathSnapshot(status: .satisfied, interfaceKinds: [.wiredEthernet])

    #expect(snapshot.isCableCandidate)
    #expect(snapshot.shortLabel == "Path Wired")
}

@Test func networkPathSnapshotLabelsUnsatisfiedPathAsUnavailable() {
    let snapshot = NetworkPathSnapshot(status: .unsatisfied, interfaceKinds: [.wifi])

    #expect(snapshot.shortLabel == "Path --")
}

@Test func networkPathSnapshotLabelsExpensiveNonCablePath() {
    let snapshot = NetworkPathSnapshot(
        status: .satisfied,
        interfaceKinds: [.cellular],
        isExpensive: true
    )

    #expect(snapshot.shortLabel == "Path Cellular Expensive")
}
