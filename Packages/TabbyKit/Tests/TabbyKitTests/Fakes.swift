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

    func snapshot() -> [MissionWindow] {
        windows
    }

    func realSize(of id: CGWindowID) -> CGSize? {
        windows.first { $0.id == id }?.frame.size
    }

    func liveFrames(of ids: [CGWindowID]) -> [CGWindowID: CGRect] {
        frames.filter { ids.contains($0.key) }
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

    func dismiss() {
        dismissals += 1
    }
}

@MainActor
final class FakeKeyboard: KeyboardIntercepting {
    var onAction: KeyboardInterceptor.ActionHandler?
    var modes: [KeyboardInterceptor.Mode] = []
    var installed = false

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
