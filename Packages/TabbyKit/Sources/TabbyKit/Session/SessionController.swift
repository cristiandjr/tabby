import AppKit
import ApplicationServices

@MainActor
public final class SessionController {
    public enum Event: Sendable {
        case opened(windows: Int)
        case selected(MissionWindow)
        case activated(MissionWindow, exact: Bool, strategy: ActivationStrategy)
        case closed
    }

    public var onEvent: (@MainActor (Event) -> Void)?
    public private(set) var isRunning = false

    public var isSessionActive: Bool {
        engine != nil
    }

    public var matchedThumbnails: Int {
        thumbnails.count
    }

    public var selectedHasThumbnail: Bool {
        engine?.selectedID.map { thumbnails[$0] != nil } ?? false
    }

    private let interceptor = KeyboardInterceptor()
    private let provider = WindowProvider()
    private let overlay = SelectionOverlay()
    private var pollTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var missionControlOpen = false
    private var closedReadings = 0
    private var renderedFrame: CGRect?
    private var highlightShown = false
    private var openedAt: ContinuousClock.Instant?
    private var engine: NavigationEngine?
    private var windows: [CGWindowID: MissionWindow] = [:]
    private var thumbnails: [CGWindowID: MissionControlThumbnail] = [:]
    private var activating = false

    public init() {}

    @discardableResult
    public func start(pollInterval: Duration = .milliseconds(50)) -> Bool {
        guard !isRunning else { return true }
        guard AX.isTrusted else { return false }
        AX.setGlobalTimeout(0.3)
        interceptor.onKey = { [weak self] key in
            self?.handle(key)
        }
        guard interceptor.install() else { return false }
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: pollInterval)
                guard let self else { return }
                self.poll()
            }
        }
        isRunning = true
        return true
    }

    public func stop() {
        pollTask?.cancel()
        pollTask = nil
        endSession()
        interceptor.uninstall()
        isRunning = false
    }

    private func poll() {
        let signature = DockAccessibility.topLevelSignature()
        guard !signature.isEmpty else { return }
        if DockAccessibility.isMissionControlOpen(signature) {
            closedReadings = 0
            guard !missionControlOpen else { return }
            missionControlOpen = true
            beginSession()
        } else {
            guard missionControlOpen else { return }
            closedReadings += 1
            guard closedReadings >= 2 else { return }
            closedReadings = 0
            missionControlOpen = false
            endSession()
        }
    }

    private func beginSession() {
        let snapshot = provider.snapshot()
        guard !snapshot.isEmpty else { return }
        windows = Dictionary(snapshot.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        engine = NavigationEngine(windowIDs: snapshot.map(\.id))
        activating = false
        renderedFrame = nil
        highlightShown = false
        openedAt = ContinuousClock().now
        resolveThumbnails()
        interceptor.setMode(.intercept)
        render()
        onEvent?(.opened(windows: snapshot.count))
        startRefreshing()
    }

    private func startRefreshing() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(tick < 15 ? 60 : 150))
                tick += 1
                guard let self, self.engine != nil, !self.activating else { return }
                self.resolveThumbnails()
                if self.selectedFrame() != self.renderedFrame || (!self.highlightShown && self.openingAnimationFinished) {
                    self.render()
                }
            }
        }
    }

    private func selectedFrame() -> CGRect? {
        engine?.selectedID.flatMap { thumbnails[$0]?.info.frame }
    }

    private var openingAnimationFinished: Bool {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion, let openedAt else { return true }
        return ContinuousClock().now - openedAt >= .milliseconds(320)
    }

    private func endSession() {
        let wasActive = engine != nil
        refreshTask?.cancel()
        refreshTask = nil
        interceptor.setMode(.off)
        overlay.hide()
        engine = nil
        windows = [:]
        thumbnails = [:]
        if wasActive {
            onEvent?(.closed)
        }
    }

    private func resolveThumbnails() {
        let found = MissionControlAccessibility.thumbnails()
        let matches = MissionControlAccessibility.match(windows: Array(windows.values), thumbnails: found.map(\.info))
        thumbnails = matches.reduce(into: [:]) { result, item in
            result[item.key] = found[item.value]
        }
    }

    private func render() {
        guard let engine, let id = engine.selectedID, let window = windows[id] else { return }
        let position = (engine.selectedIndex ?? 0) + 1
        let title = window.title.map { " — \($0)" } ?? ""
        let frame = thumbnails[id]?.info.frame
        renderedFrame = frame
        if let frame, openingAnimationFinished {
            let scale = frame.width / max(window.frame.width, 1)
            overlay.showHighlight(globalRect: frame, cornerRadius: min(max(20 * scale, 8), 44))
            highlightShown = true
        } else {
            overlay.showHighlight(globalRect: nil)
            highlightShown = false
        }
        overlay.showHUD(text: "\(window.appName)\(title)  ·  \(position)/\(engine.windowIDs.count)", near: frame ?? window.frame)
    }

    private func handle(_ key: NavigationKey) {
        guard engine != nil, !activating else { return }
        switch key {
        case .next:
            engine?.next()
            render()
            notifySelection()
        case .previous:
            engine?.previous()
            render()
            notifySelection()
        case .select:
            activate()
        }
    }

    private func notifySelection() {
        guard let id = engine?.selectedID, let window = windows[id] else { return }
        onEvent?(.selected(window))
    }

    private func activate() {
        guard let engine, let id = engine.selectedID, let window = windows[id] else { return }
        activating = true
        interceptor.setMode(.off)
        overlay.hide()
        let element = provider.element(for: id)
        let thumbnail = thumbnails[id]
        Task { @MainActor [weak self] in
            var strategy = ActivationStrategy.accessibility
            if let thumbnail {
                strategy = .dockThumbnail
                WindowActivator.pressThumbnail(thumbnail.element)
                for _ in 0..<12 where WindowActivator.focusedWindow()?.windowID != id {
                    try? await Task.sleep(for: .milliseconds(50))
                }
            }
            if WindowActivator.focusedWindow()?.windowID != id, let element {
                strategy = .accessibility
                _ = WindowActivator.activateWithAccessibility(pid: window.pid, window: element)
                try? await Task.sleep(for: .milliseconds(150))
                if DockAccessibility.isMissionControlOpen(DockAccessibility.topLevelSignature()) {
                    WindowActivator.postKey(KeyCode.escape)
                    try? await Task.sleep(for: .milliseconds(350))
                }
                if WindowActivator.focusedWindow()?.windowID != id {
                    _ = WindowActivator.activateWithAccessibility(pid: window.pid, window: element)
                    try? await Task.sleep(for: .milliseconds(150))
                }
            }
            let exact = WindowActivator.focusedWindow()?.windowID == id
            self?.onEvent?(.activated(window, exact: exact, strategy: strategy))
        }
    }
}
