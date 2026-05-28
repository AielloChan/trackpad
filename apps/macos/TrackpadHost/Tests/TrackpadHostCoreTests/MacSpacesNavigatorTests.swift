import Testing
@testable import TrackpadHostCore

@Test func targetSpaceSelectsNextSpaceOnFirstDisplay() {
    let target = MacSpacesNavigator.targetSpace(
        in: [
            display(
                id: "main",
                current: 3,
                spaces: [3, 215, 303]
            ),
        ],
        direction: .next
    )

    #expect(target?.displayID == "main")
    #expect(target?.spaceID == 215)
}

@Test func targetSpaceSelectsPreviousSpaceOnFirstDisplay() {
    let target = MacSpacesNavigator.targetSpace(
        in: [
            display(
                id: "main",
                current: 215,
                spaces: [3, 215, 303]
            ),
        ],
        direction: .previous
    )

    #expect(target?.displayID == "main")
    #expect(target?.spaceID == 3)
}

@Test func targetSpacePrefersPointerDisplayWhenAvailable() {
    let target = MacSpacesNavigator.targetSpace(
        in: [
            display(
                id: "main",
                current: 3,
                spaces: [3, 215]
            ),
            display(
                id: "pointer",
                current: 5,
                spaces: [336, 5, 303]
            ),
        ],
        direction: .next,
        preferredDisplayID: "pointer"
    )

    #expect(target?.displayID == "pointer")
    #expect(target?.spaceID == 303)
}

@Test func targetSpaceFallsBackToFirstDisplayWithAdjacentSpace() {
    let target = MacSpacesNavigator.targetSpace(
        in: [
            display(
                id: "edge",
                current: 215,
                spaces: [3, 215]
            ),
            display(
                id: "available",
                current: 5,
                spaces: [336, 5, 303]
            ),
        ],
        direction: .next,
        preferredDisplayID: "missing"
    )

    #expect(target?.displayID == "available")
    #expect(target?.spaceID == 303)
}

@Test func targetSpaceReturnsNilAtEdge() {
    let target = MacSpacesNavigator.targetSpace(
        in: [
            display(
                id: "main",
                current: 303,
                spaces: [3, 215, 303]
            ),
        ],
        direction: .next
    )

    #expect(target == nil)
}

private func display(
    id: String,
    current: UInt64,
    spaces: [UInt64]
) -> [String: Any] {
    [
        "Display Identifier": id,
        "Current Space": ["id64": current],
        "Spaces": spaces.map { ["id64": $0] },
    ]
}
