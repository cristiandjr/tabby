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
}
