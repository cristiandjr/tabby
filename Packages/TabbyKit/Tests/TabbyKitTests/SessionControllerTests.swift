import CoreGraphics
import Testing
@testable import TabbyKit

@MainActor
@Suite("SessionController")
struct SessionControllerTests {
    let monitor = FakeMonitor()
    let windows = FakeWindows()
    let thumbnails = FakeThumbnails()
    let activator = FakeActivator()
    let mover = FakeMover()
    let presenter = FakePresenter()
    let keyboard = FakeKeyboard()
    let pointer = FakePointer()
    let clock = TestClock()
    let controller: SessionController

    init() {
        controller = SessionController(dependencies: SessionDependencies(
            monitor: monitor,
            windows: windows,
            thumbnails: thumbnails,
            activator: activator,
            mover: mover,
            presenter: presenter,
            keyboard: keyboard,
            pointer: pointer,
            clock: clock
        ))
        windows.windows = [makeWindow(1, app: "Ghostty"), makeWindow(2, app: "Finder", title: "Downloads"), makeWindow(3, app: "Brave")]
        windows.frames = [
            1: CGRect(x: 100, y: 100, width: 500, height: 400),
            2: CGRect(x: 700, y: 100, width: 500, height: 400),
            3: CGRect(x: 100, y: 600, width: 500, height: 400),
        ]
    }

    private func open() {
        monitor.reading = true
        controller.poll()
    }

    private func close() {
        monitor.reading = false
        controller.poll()
        controller.poll()
    }

    private func passOpeningAnimation() {
        clock.advance(by: HighlightTracker.openingDelay)
        controller.refresh()
    }

    @Test func opensOnThePreviousWindowAndInterceptsKeys() {
        open()
        #expect(controller.state.isNavigating)
        #expect(controller.state.session?.selected?.id == 2)
        #expect(keyboard.mode == .intercept)
        #expect(presenter.prepared == [[1, 2, 3]])
        #expect(presenter.last?.label == "Finder — Downloads  ·  2/3")
    }

    @Test func onlyUsesWindowsOfTheCurrentDisplay() {
        windows.windows = [makeWindow(1, display: 7), makeWindow(2, display: 9), makeWindow(3, display: 7)]
        open()
        #expect(controller.state.session?.engine.windowIDs == [1, 3])
    }

    @Test func doesNotStartWithoutWindows() {
        windows.windows = []
        open()
        #expect(!controller.isSessionActive)
        #expect(keyboard.mode == .off)
    }

    @Test func waitsForTheOpeningAnimationBeforeHighlighting() {
        open()
        #expect(presenter.last?.isHighlighted == false)
        passOpeningAnimation()
        #expect(presenter.last?.isHighlighted == true)
        #expect(presenter.last?.thumbnailFrame == windows.frames[2])
    }

    @Test func tabAndShiftTabMoveTheSelectionAndWrap() {
        open()
        controller.perform(.next)
        #expect(controller.state.session?.selected?.id == 3)
        controller.perform(.next)
        #expect(controller.state.session?.selected?.id == 1)
        controller.perform(.previous)
        #expect(controller.state.session?.selected?.id == 3)
        #expect(presenter.last?.windowID == 3)
    }

    @Test func followsTheLiveThumbnailFrame() {
        open()
        passOpeningAnimation()
        windows.frames[2] = CGRect(x: 650, y: 80, width: 420, height: 336)
        controller.refresh()
        #expect(presenter.last?.thumbnailFrame == CGRect(x: 650, y: 80, width: 420, height: 336))
    }

    @Test func doesNotRepeatAnUnchangedPresentation() {
        open()
        passOpeningAnimation()
        let count = presenter.presentations.count
        controller.refresh()
        controller.refresh()
        #expect(presenter.presentations.count == count)
    }

    @Test func includesTheNeighborsForPrefetching() {
        open()
        #expect(Set(presenter.last.map { Array($0.neighborFrames.keys) } ?? []) == [1, 3])
    }

    @Test func movingThePointerHandsOverAndTabReclaims() {
        open()
        passOpeningAnimation()
        pointer.move(to: CGPoint(x: 4, y: 4))
        #expect(presenter.last?.isHighlighted == true)
        pointer.move(to: CGPoint(x: 40, y: 40))
        #expect(presenter.last?.isHighlighted == false)
        controller.perform(.next)
        #expect(presenter.last?.isHighlighted == true)
        #expect(presenter.last?.windowID == 3)
    }

    @Test func returnActivatesTheSelectedWindowWithItsThumbnail() async {
        var activated: (MissionWindow, ActivationResult)?
        controller.onEvent = { event in
            if case .activated(let window, let result) = event { activated = (window, result) }
        }
        open()
        controller.perform(.next)
        controller.perform(.activate)
        if case .activating(_, let target) = controller.state {
            #expect(target == 3)
        } else {
            Issue.record("expected the activating state")
        }
        #expect(keyboard.mode == .off)
        #expect(presenter.dismissals == 1)
        await Task.yield()
        await Task.yield()
        #expect(activator.calls.map(\.window.id) == [3])
        #expect(activator.calls.first?.hadThumbnail == true)
        #expect(activated?.0.id == 3)
    }

    @Test func activatesWithoutAThumbnailToo() async {
        thumbnails.available = []
        open()
        controller.perform(.activate)
        await Task.yield()
        await Task.yield()
        #expect(activator.calls.first?.hadThumbnail == false)
    }

    @Test func ignoresKeysWhileActivatingOrIdle() {
        controller.perform(.next)
        #expect(!controller.isSessionActive)
        open()
        controller.perform(.activate)
        controller.perform(.next)
        controller.perform(.activate)
        #expect(controller.state.session?.selected?.id == 2)
    }

    @Test func closingNeedsTwoReadingsAndIgnoresUnknownOnes() {
        var closed = 0
        controller.onEvent = { event in
            if case .closed = event { closed += 1 }
        }
        open()
        monitor.reading = nil
        controller.poll()
        monitor.reading = false
        controller.poll()
        #expect(controller.isSessionActive)
        controller.poll()
        #expect(!controller.isSessionActive)
        #expect(keyboard.mode == .off)
        #expect(presenter.dismissals == 1)
        #expect(closed == 1)
    }

    @Test func aBriefClosedReadingDoesNotEndTheSession() {
        open()
        monitor.reading = false
        controller.poll()
        monitor.reading = true
        controller.poll()
        monitor.reading = false
        controller.poll()
        #expect(controller.isSessionActive)
    }

    @Test func reopeningStartsAFreshSession() {
        open()
        controller.perform(.next)
        close()
        open()
        #expect(controller.state.session?.selected?.id == 2)
        #expect(presenter.prepared.count == 2)
    }

    @Test func refreshesThumbnailsThatWereMissing() {
        thumbnails.available = [1]
        open()
        #expect(controller.matchedThumbnails == 1)
        thumbnails.available = nil
        controller.refresh()
        #expect(controller.matchedThumbnails == 3)
        #expect(controller.selectedHasThumbnail)
    }

    @Test func commandNumberMovesTheSelectedWindowAndSelectsTheNextOne() async {
        var moved: (CGWindowID, Int)?
        controller.onEvent = { event in
            if case .moved(let window, let desktop, _) = event { moved = (window.id, desktop) }
        }
        open()
        controller.perform(.moveToDesktop(3))
        if case .movingWindow(_, let target, let desktop) = controller.state {
            #expect(target == 2)
            #expect(desktop == 3)
        } else {
            Issue.record("expected the moving state")
        }
        await Task.yield()
        await Task.yield()
        #expect(mover.calls.map(\.desktop) == [3])
        #expect(controller.state.isNavigating)
        #expect(controller.state.session?.engine.windowIDs == [1, 3])
        #expect(controller.state.session?.selected?.id == 3)
        #expect(moved?.0 == 2)
        #expect(keyboard.mode == .intercept)
        #expect(presenter.prepared.count == 2)
    }

    @Test func ignoresKeysWhileMovingAWindow() async {
        open()
        controller.perform(.moveToDesktop(2))
        controller.perform(.next)
        controller.perform(.moveToDesktop(4))
        await Task.yield()
        await Task.yield()
        #expect(mover.calls.map(\.desktop) == [2])
        #expect(controller.state.session?.selected?.id == 3)
    }

    @Test func aFailedMoveKeepsTheWindowAndShowsANotice() async {
        mover.result = .failed(.dropRejected, createdDesktops: 0)
        open()
        controller.perform(.moveToDesktop(5))
        await Task.yield()
        await Task.yield()
        #expect(controller.state.session?.engine.windowIDs == [1, 2, 3])
        #expect(controller.state.session?.selected?.id == 2)
        #expect(presenter.notices.count == 1)
    }

    @Test func explainsWhyAWindowOnAllDesktopsCannotMove() async {
        mover.result = .failed(.onAllDesktops, createdDesktops: 0)
        open()
        controller.perform(.moveToDesktop(2))
        await Task.yield()
        await Task.yield()
        #expect(presenter.notices.first?.contains("Finder") == true)
    }

    @Test func closingMissionControlDuringAMoveEndsTheSession() async {
        open()
        controller.perform(.moveToDesktop(2))
        close()
        await Task.yield()
        await Task.yield()
        #expect(!controller.isSessionActive)
    }

    @Test func movingTheLastWindowLeavesAnEmptySession() async {
        windows.windows = [makeWindow(1)]
        open()
        controller.perform(.moveToDesktop(2))
        await Task.yield()
        await Task.yield()
        #expect(controller.state.isNavigating)
        #expect(controller.state.session?.selected == nil)
        controller.perform(.next)
        controller.perform(.activate)
        #expect(activator.calls.isEmpty)
    }

    private func switchDesktop(to newWindows: [MissionWindow]) {
        windows.windows = newWindows
        controller.refresh()
        clock.advance(by: SessionController.desktopStableTime)
        controller.refresh()
    }

    @Test func switchingDesktopsInsideMissionControlRebuildsTheSession() {
        var changed: Int?
        controller.onEvent = { event in
            if case .desktopChanged(let count) = event { changed = count }
        }
        open()
        controller.perform(.next)
        clock.advance(by: SessionController.openingSettleTime)
        windows.frames[7] = CGRect(x: 200, y: 150, width: 600, height: 450)
        switchDesktop(to: [makeWindow(7, app: "Sublime"), makeWindow(8, app: "Notes")])
        #expect(controller.state.session?.engine.windowIDs == [7, 8])
        #expect(controller.state.session?.selected?.id == 7)
        #expect(presenter.dismissals == 1)
        #expect(presenter.prepared.count == 2)
        #expect(presenter.last?.windowID == 7)
        #expect(presenter.last?.isHighlighted == false)
        #expect(keyboard.mode == .intercept)
        #expect(changed == 2)
        clock.advance(by: HighlightTracker.openingDelay)
        controller.refresh()
        #expect(presenter.last?.windowID == 7)
        #expect(presenter.last?.isHighlighted == true)
    }

    @Test func hidesTheStaleHighlightAndWaitsForTheTransitionToSettle() {
        open()
        clock.advance(by: SessionController.openingSettleTime)
        windows.windows = [makeWindow(1)]
        controller.refresh()
        #expect(presenter.dismissals == 1)
        clock.advance(by: .milliseconds(60))
        windows.windows = [makeWindow(1), makeWindow(7)]
        controller.refresh()
        clock.advance(by: .milliseconds(60))
        windows.windows = [makeWindow(7)]
        controller.refresh()
        clock.advance(by: .milliseconds(60))
        controller.refresh()
        #expect(controller.state.session?.engine.windowIDs == [1, 2, 3])
        clock.advance(by: SessionController.desktopStableTime)
        controller.refresh()
        #expect(controller.state.session?.engine.windowIDs == [7])
        #expect(presenter.prepared.count == 2)
    }

    @Test func stopsWaitingWhenTheDesktopKeepsChanging() {
        open()
        clock.advance(by: SessionController.openingSettleTime)
        for step in 0..<18 {
            windows.windows = step.isMultiple(of: 2) ? [makeWindow(7)] : [makeWindow(7), makeWindow(8)]
            controller.refresh()
            clock.advance(by: .milliseconds(60))
        }
        #expect(controller.state.session?.engine.windowIDs == [7, 8])
    }

    @Test func returnAsTheDesktopStartsSlidingWaitsForTheNewDesktop() async {
        open()
        clock.advance(by: SessionController.openingSettleTime)
        controller.refresh()
        windows.frames[1] = CGRect(x: -200, y: 100, width: 500, height: 400)
        controller.perform(.activate)
        #expect(activator.calls.isEmpty)
        clock.advance(by: .milliseconds(60))
        windows.windows = [makeWindow(7)]
        controller.refresh()
        clock.advance(by: SessionController.desktopStableTime)
        controller.refresh()
        await Task.yield()
        await Task.yield()
        #expect(activator.calls.map(\.window.id) == [7])
    }

    @Test func keysWorkRightAwayWhileTheNewDesktopFinishesSliding() async {
        open()
        clock.advance(by: SessionController.openingSettleTime)
        windows.frames[7] = CGRect(x: 600, y: 100, width: 500, height: 400)
        switchDesktop(to: [makeWindow(7), makeWindow(8)])
        windows.frames[7] = CGRect(x: 500, y: 100, width: 500, height: 400)
        controller.perform(.activate)
        await Task.yield()
        await Task.yield()
        #expect(activator.calls.map(\.window.id) == [7])
    }

    @Test func aFailedMoveKeepsItsNoticeWhileTheThumbnailSettles() async {
        mover.result = .failed(.dropRejected, createdDesktops: 0)
        open()
        clock.advance(by: SessionController.openingSettleTime)
        controller.perform(.moveToDesktop(2))
        await Task.yield()
        await Task.yield()
        let dismissals = presenter.dismissals
        windows.frames[2] = CGRect(x: 640, y: 160, width: 500, height: 400)
        controller.refresh()
        #expect(presenter.dismissals == dismissals)
        #expect(presenter.notices.count == 1)
    }

    @Test func movingThumbnailsHideTheHighlightUntilTheyStop() {
        var changes = 0
        controller.onEvent = { event in
            if case .desktopChanged = event { changes += 1 }
        }
        open()
        clock.advance(by: SessionController.openingSettleTime)
        controller.refresh()
        #expect(presenter.last?.isHighlighted == true)
        windows.frames[2] = CGRect(x: 600, y: 100, width: 500, height: 400)
        controller.refresh()
        #expect(presenter.dismissals == 1)
        clock.advance(by: .milliseconds(30))
        windows.frames[2] = CGRect(x: 560, y: 100, width: 500, height: 400)
        controller.refresh()
        clock.advance(by: .milliseconds(60))
        controller.refresh()
        #expect(presenter.dismissals == 1)
        clock.advance(by: SessionController.desktopStableTime)
        controller.refresh()
        #expect(changes == 0)
        #expect(controller.state.session?.selected?.id == 2)
        #expect(presenter.last?.isHighlighted == true)
        #expect(presenter.last?.thumbnailFrame == CGRect(x: 560, y: 100, width: 500, height: 400))
    }

    @Test func returnDuringADesktopSwitchActivatesAWindowOfTheNewDesktop() async {
        open()
        clock.advance(by: SessionController.openingSettleTime)
        windows.windows = [makeWindow(7), makeWindow(8)]
        controller.perform(.activate)
        #expect(controller.state.isNavigating)
        #expect(activator.calls.isEmpty)
        clock.advance(by: SessionController.desktopStableTime)
        controller.refresh()
        await Task.yield()
        await Task.yield()
        #expect(activator.calls.map(\.window.id) == [7])
    }

    @Test func returnActivatesAWindowOfTheDesktopShownInMissionControl() async {
        open()
        clock.advance(by: SessionController.openingSettleTime)
        switchDesktop(to: [makeWindow(7), makeWindow(8)])
        controller.perform(.activate)
        await Task.yield()
        await Task.yield()
        #expect(activator.calls.map(\.window.id) == [7])
    }

    @Test func tabDuringADesktopSwitchMovesThroughTheNewDesktop() {
        open()
        clock.advance(by: SessionController.openingSettleTime)
        windows.windows = [makeWindow(7), makeWindow(8), makeWindow(9)]
        controller.perform(.next)
        controller.perform(.next)
        #expect(controller.state.session?.engine.windowIDs == [1, 2, 3])
        clock.advance(by: SessionController.desktopStableTime)
        controller.refresh()
        #expect(controller.state.session?.selected?.id == 9)
        #expect(presenter.last?.windowID == 9)
    }

    @Test func comingBackToTheSameDesktopKeepsTheSelection() {
        var changes = 0
        controller.onEvent = { event in
            if case .desktopChanged = event { changes += 1 }
        }
        open()
        controller.perform(.next)
        clock.advance(by: SessionController.openingSettleTime)
        let original = windows.windows
        let shown = presenter.presentations.count
        windows.windows = [makeWindow(7)]
        controller.refresh()
        clock.advance(by: .milliseconds(60))
        windows.windows = original
        controller.refresh()
        clock.advance(by: SessionController.desktopStableTime)
        controller.refresh()
        #expect(changes == 0)
        #expect(controller.state.session?.engine.windowIDs == [1, 2, 3])
        #expect(controller.state.session?.selected?.id == 3)
        #expect(presenter.presentations.count == shown + 1)
        #expect(presenter.last?.windowID == 3)
    }

    @Test func keepsTheSelectionWhenAWindowOfTheDesktopCloses() {
        open()
        controller.perform(.next)
        clock.advance(by: SessionController.openingSettleTime)
        switchDesktop(to: windows.windows.filter { $0.id != 1 })
        #expect(controller.state.session?.engine.windowIDs == [2, 3])
        #expect(controller.state.session?.selected?.id == 3)
    }

    @Test func closingMissionControlDuringADesktopSwitchDropsTheQueuedKeys() async {
        open()
        clock.advance(by: SessionController.openingSettleTime)
        windows.windows = [makeWindow(7)]
        controller.perform(.activate)
        close()
        clock.advance(by: SessionController.desktopStableTime)
        controller.refresh()
        await Task.yield()
        #expect(activator.calls.isEmpty)
        #expect(!controller.isSessionActive)
    }

    @Test func doesNotRebuildWhileTheDesktopStaysTheSame() {
        open()
        controller.perform(.next)
        clock.advance(by: SessionController.openingSettleTime)
        controller.refresh()
        controller.refresh()
        #expect(presenter.prepared.count == 1)
        #expect(controller.state.session?.selected?.id == 3)
    }

    @Test func ignoresChangesWhileMissionControlIsStillOpening() {
        open()
        windows.windows = [makeWindow(7)]
        controller.refresh()
        #expect(controller.state.session?.engine.windowIDs == [1, 2, 3])
    }

    @Test func comesBackFromAnEmptyDesktop() {
        open()
        let original = windows.windows
        clock.advance(by: SessionController.openingSettleTime)
        switchDesktop(to: [])
        #expect(controller.state.session?.selected == nil)
        switchDesktop(to: original)
        #expect(controller.state.session?.engine.windowIDs == [1, 2, 3])
        #expect(controller.state.session?.selected?.id == 1)
    }

    @Test func movingAWindowDoesNotLookLikeADesktopChange() async {
        open()
        clock.advance(by: SessionController.openingSettleTime)
        controller.perform(.moveToDesktop(3))
        windows.windows = windows.windows.filter { $0.id != 2 }
        await Task.yield()
        await Task.yield()
        controller.refresh()
        #expect(controller.state.session?.selected?.id == 3)
        #expect(controller.state.session?.engine.windowIDs == [1, 3])
    }
}
