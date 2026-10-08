import AppKit
import ApplicationServices

public struct ActivationResult: Equatable, Sendable {
    public var exact: Bool
    public var strategy: ActivationStrategy
    public var elapsed: Duration

    public init(exact: Bool, strategy: ActivationStrategy, elapsed: Duration) {
        self.exact = exact
        self.strategy = strategy
        self.elapsed = elapsed
    }
}

@MainActor
public protocol WindowActivating: AnyObject {
    func activate(_ window: MissionWindow, thumbnail: MissionControlThumbnail?) async -> ActivationResult
}

@MainActor
public protocol ActivationSystem: AnyObject {
    var isMissionControlOpen: Bool { get }
    func press(_ thumbnail: MissionControlThumbnail)
    func sendEscape()
    func requestFocus(on window: MissionWindow)
    func isFocused(_ window: MissionWindow) -> Bool
}

@MainActor
public final class ActivationCoordinator: WindowActivating {
    public struct Timing: Sendable {
        public var closeAfterPress: Duration = .milliseconds(300)
        public var closeAfterEscape: Duration = .milliseconds(500)
        public var focus: Duration = .milliseconds(700)
        public var focusRetry: Duration = .milliseconds(80)
        public var poll: Duration = .milliseconds(10)

        public init() {}
    }

    private let system: any ActivationSystem
    private let clock: any SessionClock
    private let timing: Timing

    public init(system: any ActivationSystem, clock: any SessionClock = SystemClock(), timing: Timing = Timing()) {
        self.system = system
        self.clock = clock
        self.timing = timing
    }

    public func activate(_ window: MissionWindow, thumbnail: MissionControlThumbnail?) async -> ActivationResult {
        let started = clock.now
        var strategy: ActivationStrategy = thumbnail == nil ? .accessibility : .dockThumbnail
        if let thumbnail {
            system.press(thumbnail)
            await waitUntilMissionControlCloses(timeout: timing.closeAfterPress)
        }
        if system.isMissionControlOpen {
            strategy = .accessibility
            system.sendEscape()
            await waitUntilMissionControlCloses(timeout: timing.closeAfterEscape)
        }
        let exact = await focus(window)
        return ActivationResult(exact: exact, strategy: strategy, elapsed: clock.now - started)
    }

    private func waitUntilMissionControlCloses(timeout: Duration) async {
        let deadline = clock.now + timeout
        while system.isMissionControlOpen, clock.now < deadline {
            await clock.sleep(for: timing.poll)
        }
    }

    private func focus(_ window: MissionWindow) async -> Bool {
        let deadline = clock.now + timing.focus
        var nextRequest = clock.now
        while !system.isFocused(window) {
            guard clock.now < deadline else { return false }
            if clock.now >= nextRequest {
                system.requestFocus(on: window)
                nextRequest = clock.now + timing.focusRetry
            }
            await clock.sleep(for: timing.poll)
        }
        return true
    }
}

@MainActor
public final class LiveActivationSystem: ActivationSystem {
    private let windows: WindowProvider

    public init(windows: WindowProvider) {
        self.windows = windows
    }

    public var isMissionControlOpen: Bool {
        DockAccessibility.isMissionControlOpen(DockAccessibility.topLevelSignature())
    }

    public func press(_ thumbnail: MissionControlThumbnail) {
        WindowActivator.pressThumbnail(thumbnail.element)
    }

    public func sendEscape() {
        WindowActivator.postKey(KeyCode.escape)
    }

    public func requestFocus(on window: MissionWindow) {
        guard let element = windows.element(for: window.id) else { return }
        _ = WindowActivator.activateWithAccessibility(pid: window.pid, window: element)
    }

    public func isFocused(_ window: MissionWindow) -> Bool {
        WindowActivator.isFocused(window.id, pid: window.pid)
    }
}
