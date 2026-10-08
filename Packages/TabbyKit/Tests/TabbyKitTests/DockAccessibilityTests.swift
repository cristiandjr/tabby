import Testing
@testable import TabbyKit

@Suite("DockAccessibility")
struct DockAccessibilityTests {
    @Test func detectsTheMissionControlGroup() {
        #expect(DockAccessibility.isMissionControlOpen(["AXList", "AXGroup:mc"]))
    }

    @Test func ignoresTheAppSwitcherList() {
        #expect(!DockAccessibility.isMissionControlOpen(["AXList", "AXList"]))
    }

    @Test func ignoresTheIdleDock() {
        #expect(!DockAccessibility.isMissionControlOpen(["AXList"]))
        #expect(!DockAccessibility.isMissionControlOpen([]))
    }
}
