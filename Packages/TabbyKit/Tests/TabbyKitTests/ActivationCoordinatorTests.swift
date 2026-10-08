import Testing
@testable import TabbyKit

@MainActor
@Suite("ActivationCoordinator")
struct ActivationCoordinatorTests {
    let system = FakeActivationSystem()
    let clock = TestClock()
    let window = makeWindow(42)

    private var coordinator: ActivationCoordinator {
        ActivationCoordinator(system: system, clock: clock)
    }

    @Test func pressesTheThumbnailAndFocusesRightAfterMissionControlCloses() async {
        let result = await coordinator.activate(window, thumbnail: makeThumbnail(for: 42))
        #expect(result.exact)
        #expect(result.strategy == .dockThumbnail)
        #expect(system.presses == 1)
        #expect(system.escapes == 0)
        #expect(system.focusRequests == 1)
    }

    @Test func doesNotRequestFocusWhenThePressAlreadyFocused() async {
        system.focusOnPress = true
        let result = await coordinator.activate(window, thumbnail: makeThumbnail(for: 42))
        #expect(result.exact)
        #expect(system.focusRequests == 0)
    }

    @Test func retriesFocusUntilTheWindowIsFocused() async {
        system.focusAfterRequests = 3
        let result = await coordinator.activate(window, thumbnail: makeThumbnail(for: 42))
        #expect(result.exact)
        #expect(system.focusRequests == 3)
        #expect(result.elapsed >= .milliseconds(160))
    }

    @Test func fallsBackToEscapeWhenThePressDoesNotCloseMissionControl() async {
        system.pressClosesMissionControl = false
        let result = await coordinator.activate(window, thumbnail: makeThumbnail(for: 42))
        #expect(result.exact)
        #expect(result.strategy == .accessibility)
        #expect(system.escapes == 1)
        #expect(result.elapsed >= .milliseconds(300))
    }

    @Test func closesWithEscapeFirstWithoutAThumbnail() async {
        let result = await coordinator.activate(window, thumbnail: nil)
        #expect(result.exact)
        #expect(result.strategy == .accessibility)
        #expect(system.presses == 0)
        #expect(system.escapes == 1)
    }

    @Test func neverSendsEscapeOnceMissionControlIsClosed() async {
        system.isMissionControlOpen = false
        let result = await coordinator.activate(window, thumbnail: nil)
        #expect(result.exact)
        #expect(system.escapes == 0)
    }

    @Test func givesUpAfterTheFocusTimeout() async {
        system.focusAfterRequests = .max
        let result = await coordinator.activate(window, thumbnail: makeThumbnail(for: 42))
        #expect(!result.exact)
        #expect(result.elapsed >= .milliseconds(700))
        #expect(result.elapsed < .milliseconds(900))
    }
}
