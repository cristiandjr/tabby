import ApplicationServices
import CoreGraphics
import Foundation
@testable import TabbyKit

final class TestClock: SessionClock, @unchecked Sendable {
    private let lock = NSLock()
    private var current = ContinuousClock().now

    var now: ContinuousClock.Instant {
        lock.withLock { current }
    }

    func sleep(for duration: Duration, tolerance: Duration?) async {
        advance(by: duration)
        await Task.yield()
    }

    func advance(by duration: Duration) {
        lock.withLock { current = current + duration }
    }
}

func makeWindow(_ id: CGWindowID, display: CGDirectDisplayID = 1, app: String = "App", title: String? = nil) -> MissionWindow {
    MissionWindow(
        id: id,
        pid: pid_t(id),
        bundleID: "test.\(app)",
        appName: app,
        title: title,
        frame: CGRect(x: 0, y: 0, width: 1000, height: 800),
        displayID: display,
        zIndex: Int(id)
    )
}

func makeThumbnail(for id: CGWindowID) -> MissionControlThumbnail {
    MissionControlThumbnail(
        element: AXUIElementCreateApplication(pid_t(id)),
        info: ThumbnailInfo(bundleID: "test", spaceID: "1", title: nil, frame: .zero, windowID: id)
    )
}

@MainActor
final class FakeMonitor: MissionControlMonitoring {
    var reading: Bool? = false

    func isOpen() -> Bool? {
        reading
    }
}

@MainActor
final class FakeWindows: WindowProviding {
    var windows: [MissionWindow] = []
    var frames: [CGWindowID: CGRect] = [:]
    var missingFromSnapshot: Set<CGWindowID> = []

    func snapshot() -> [MissionWindow] {
        windows.filter { !missingFromSnapshot.contains($0.id) }
    }

    func realSize(of id: CGWindowID) -> CGSize? {
        windows.first { $0.id == id }?.frame.size
    }

    func liveFrames(of ids: [CGWindowID]) -> [CGWindowID: CGRect] {
        frames.filter { ids.contains($0.key) }
    }

    func visibleWindowIDs(on display: CGDirectDisplayID) -> Set<CGWindowID> {
        Set(windows.filter { $0.displayID == display }.map(\.id))
    }
}

@MainActor
final class FakeThumbnails: ThumbnailProviding {
    var available: Set<CGWindowID>?

    func thumbnails(for windows: [MissionWindow]) -> [CGWindowID: MissionControlThumbnail] {
        windows.reduce(into: [:]) { result, window in
            if available?.contains(window.id) ?? true {
                result[window.id] = makeThumbnail(for: window.id)
            }
        }
    }
}

@MainActor
final class FakeActivator: WindowActivating {
    var calls: [(window: MissionWindow, hadThumbnail: Bool)] = []
    var result = ActivationResult(exact: true, strategy: .dockThumbnail, elapsed: .milliseconds(30))

    func activate(_ window: MissionWindow, thumbnail: MissionControlThumbnail?) async -> ActivationResult {
        calls.append((window, thumbnail != nil))
        return result
    }
}

@MainActor
final class FakePresenter: SelectionPresenting {
    var prepared: [[CGWindowID]] = []
    var presentations: [SelectionPresentation] = []
    var notices: [String] = []
    var dismissals = 0

    var last: SelectionPresentation? {
        presentations.last
    }

    func prepare(for windows: [MissionWindow]) {
        prepared.append(windows.map(\.id))
    }

    func present(_ presentation: SelectionPresentation) {
        presentations.append(presentation)
    }

    func showNotice(_ text: String) {
        notices.append(text)
    }

    func dismiss() {
        dismissals += 1
    }
}

@MainActor
final class FakeMover: SpaceMoving {
    var calls: [(window: CGWindowID, desktop: Int)] = []
    var result = SpaceMoveResult.moved(createdDesktops: 0)

    func move(_ window: MissionWindow, toDesktop number: Int) async -> SpaceMoveResult {
        calls.append((window.id, number))
        return result
    }
}

@MainActor
final class FakeSpaceSystem: SpaceSystem {
    var pointerLocation = CGPoint(x: 500, y: 500)
    var onAllDesktops = false
    var thumbnail: CGRect? = CGRect(x: 100, y: 400, width: 300, height: 200)
    var hasBar = true
    var desktopCount = 2
    var addCreatesDesktop = true
    var expandsAfterDrags = 3
    var acceptsDrop = true
    private(set) var events: [PointerEvent] = []
    private(set) var additions = 0
    private var drags = 0
    private var dropped = false
    let display = CGRect(x: 0, y: 0, width: 1920, height: 1080)

    func isOnAllDesktops(_ window: MissionWindow) -> Bool {
        onAllDesktops
    }

    func thumbnailFrame(of window: MissionWindow) -> CGRect? {
        thumbnail
    }

    func spacesBar(containing point: CGPoint) -> SpacesBar? {
        guard hasBar else { return nil }
        let y: CGFloat = drags >= expandsAfterDrags ? 102 : -33
        return SpacesBar(displayFrame: display, desktopCenters: (0..<desktopCount).map { CGPoint(x: 768 + CGFloat($0) * 192, y: y) })
    }

    func addDesktop(containing point: CGPoint) {
        additions += 1
        if addCreatesDesktop { desktopCount += 1 }
    }

    func isOnCurrentDesktop(_ window: MissionWindow) -> Bool {
        !dropped
    }

    func post(_ event: PointerEvent) {
        events.append(event)
        switch event {
        case .drag:
            drags += 1
        case .up(let point):
            dropped = acceptsDrop && point.y > display.minY + 60
        default:
            break
        }
    }

    var downs: Int { events.filter { if case .down = $0 { return true }; return false }.count }
    var ups: Int { events.filter { if case .up = $0 { return true }; return false }.count }
    var lastWarp: CGPoint? {
        events.compactMap { if case .warp(let point) = $0 { return point }; return nil }.last
    }
}

@MainActor
final class FakeKeyboard: KeyboardIntercepting {
    var onAction: KeyboardInterceptor.ActionHandler?
    var keymap = Keymap.standard
    var modes: [KeyboardInterceptor.Mode] = []
    var installed = false
    var timeoutCount = 0

    var isInstalled: Bool {
        installed
    }

    var mode: KeyboardInterceptor.Mode {
        modes.last ?? .off
    }

    func install() -> Bool {
        installed = true
        return true
    }

    func uninstall() {
        installed = false
    }

    func setMode(_ mode: KeyboardInterceptor.Mode) {
        modes.append(mode)
    }
}

@MainActor
final class FakePointer: PointerMonitoring {
    var location: CGPoint = .zero
    var onMove: (@MainActor (CGPoint) -> Void)?

    func start(onMove: @escaping @MainActor (CGPoint) -> Void) {
        self.onMove = onMove
    }

    func stop() {
        onMove = nil
    }

    func move(to point: CGPoint) {
        location = point
        onMove?(point)
    }
}

@MainActor
final class FakeActivationSystem: ActivationSystem {
    var isMissionControlOpen = true
    var pressClosesMissionControl = true
    var escapeClosesMissionControl = true
    var focusAfterRequests = 1
    var focusOnPress = false
    private(set) var presses = 0
    private(set) var escapes = 0
    private(set) var focusRequests = 0
    private var focused = false

    func press(_ thumbnail: MissionControlThumbnail) {
        presses += 1
        if pressClosesMissionControl { isMissionControlOpen = false }
        if focusOnPress { focused = true }
    }

    func sendEscape() {
        escapes += 1
        if escapeClosesMissionControl { isMissionControlOpen = false }
    }

    func requestFocus(on window: MissionWindow) {
        focusRequests += 1
        if focusRequests >= focusAfterRequests { focused = true }
    }

    func isFocused(_ window: MissionWindow) -> Bool {
        focused
    }
}
