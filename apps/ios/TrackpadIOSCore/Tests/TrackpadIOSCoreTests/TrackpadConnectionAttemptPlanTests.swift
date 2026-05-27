import Foundation
import Testing
@testable import TrackpadIOSCore

@Test func connectionAttemptPlanPrefersWiredBeforeDefaultPath() {
    let attempts = TrackpadConnectionAttemptPlan(
        prefersWiredEthernet: true,
        wiredAttemptTimeout: 0.6
    )
    .attempts(defaultTimeout: 3)

    #expect(attempts == [
        TrackpadConnectionAttempt(interfaceRequirement: .wiredEthernet, timeout: 0.6),
        TrackpadConnectionAttempt(interfaceRequirement: nil, timeout: 3),
    ])
}

@Test func connectionAttemptPlanCanUseDefaultPathOnly() {
    let attempts = TrackpadConnectionAttemptPlan(prefersWiredEthernet: false)
        .attempts(defaultTimeout: 3)

    #expect(attempts == [
        TrackpadConnectionAttempt(interfaceRequirement: nil, timeout: 3),
    ])
}
