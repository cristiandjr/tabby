import AppKit

@MainActor
public final class SessionController {
    public enum Event {
        case opened(windows: Int)
        case selected(MissionWindow)
        case activated(MissionWindow, ActivationResult)
        case moved(MissionWindow, desktop: Int, SpaceMoveResult)
        case desktopChanged(windows: Int)
        case closed
    }

    public var onEvent: (@MainActor (Event) -> Void)?
    public private(set) var isRunning = false
    public private(set) var state: SessionState = .idle

    public var isSessionActive: Bool {
        state.session != nil
    }

    public var matchedThumbnails: Int {
        state.session?.thumbnails.count ?? 0
    }

    public var selectedHasThumbnail: Bool {
        guard let session = state.session, let id = session.engine.selectedID else { return false }
        return session.thumbnails[id] != nil
    }

    public var keyboardTapInstalled: Bool {
        dependencies.keyboard.isInstalled
    }

    public var keyboardTapTimeouts: Int {
        dependencies.keyboard.timeoutCount
    }

    static let openingSettleTime: Duration = .milliseconds(400)
    static let desktopStableTime: Duration = .milliseconds(100)
    static let desktopChangeTimeout: Duration = .seconds(1)
    static let desktopMatchTimeout: Duration = .seconds(2)
    static let desktopMotionThreshold: CGFloat = 10

    private struct DesktopChange {
        var visible: Set<CGWindowID>
        var frames: [CGWindowID: CGRect]
        var stableSince: ContinuousClock.Instant
        let detectedAt: ContinuousClock.Instant
    }

    private let dependencies: SessionDependencies
    private let log = Log.logger("session")
    private var detector = MissionControlDetector()
    private var tracker = HighlightTracker()
    private var presented: SelectionPresentation?
    private var refreshTick = 0
    private var pollTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var desktopChange: DesktopChange?
    private var motionGraceEnd: ContinuousClock.Instant?
    private var pendingActions: [SessionAction] = []

    public convenience init() {
        self.init(dependencies: .live())
    }

    public init(dependencies: SessionDependencies) {
        self.dependencies = dependencies
    }

    @discardableResult
    public func start(pollInterval: Duration = .milliseconds(100)) -> Bool {
        guard !isRunning else { return true }
        guard AX.isTrusted else { return false }
        AX.setGlobalTimeout(0.3)
        dependencies.keyboard.onAction = { [weak self] action in
            self?.perform(action)
        }
        guard dependencies.keyboard.install() else { return false }
        let clock = dependencies.clock
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await clock.sleep(for: pollInterval, tolerance: pollInterval / 4)
                guard let self, !Task.isCancelled else { return }
                self.poll()
            }
        }
        isRunning = true
        return true
    }

    public func setKeymap(_ keymap: Keymap) {
        dependencies.keyboard.keymap = keymap
    }

    public func stop() {
        pollTask?.cancel()
        pollTask = nil
        finishSession()
        detector.reset()
        dependencies.keyboard.uninstall()
        isRunning = false
    }

    func poll() {
        switch detector.feed(dependencies.monitor.isOpen()) {
        case .opened:
            beginSession()
        case .closed:
            finishSession()
        case nil:
            break
        }
    }

    func perform(_ action: SessionAction) {
        guard case .navigating(var session) = state else { return }
        if desktopChange != nil || beginsDesktopChange(in: session) {
            pendingActions.append(action)
            return
        }
        switch action {
        case .next, .previous:
            session.move(action)
            state = .navigating(session)
            tracker.reclaim(pointer: dependencies.pointer.location)
            render()
            if let window = session.selected {
                onEvent?(.selected(window))
            }
        case .activate:
            activate(session)
        case .moveToDesktop(let number):
            move(session, toDesktop: number)
        }
    }

    func refresh() {
        guard case .navigating(var session) = state else { return }
        if desktopChange != nil {
            settleDesktopChange(in: session)
            return
        }
        if beginsDesktopChange(in: session) { return }
        refreshTick += 1
        tracker.update(liveFrames: dependencies.windows.liveFrames(of: session.engine.windowIDs))
        if refreshTick % 4 == 0 || session.thumbnails.count < session.windows.count {
            session.thumbnails = dependencies.thumbnails.thumbnails(for: Array(session.windows.values))
            state = .navigating(session)
        }
        render()
    }

    func pointerMoved(to location: CGPoint) {
        guard state.isNavigating, tracker.pointerMoved(to: location) else { return }
        render()
    }

    private func beginSession() {
        guard state.session == nil else { return }
        let all = dependencies.windows.snapshot()
        guard let display = all.first?.displayID else { return }
        let windows = all.filter { $0.displayID == display }
        var session = NavigationSession(windows: windows, display: display, startedAt: dependencies.clock.now)
        session.thumbnails = dependencies.thumbnails.thumbnails(for: windows)
        session.visibleWindows = dependencies.windows.visibleWindowIDs(on: display)
        startTracking(windows)
        presented = nil
        refreshTick = 0
        state = .navigating(session)
        dependencies.keyboard.setMode(.intercept)
        dependencies.presenter.prepare(for: windows)
        render()
        onEvent?(.opened(windows: windows.count))
        startRefreshing()
        dependencies.pointer.start { [weak self] location in
            self?.pointerMoved(to: location)
        }
    }

    private func beginsDesktopChange(in session: NavigationSession) -> Bool {
        let now = dependencies.clock.now
        guard now - session.startedAt >= Self.openingSettleTime else { return false }
        let visible = dependencies.windows.visibleWindowIDs(on: session.display)
        let frames = dependencies.windows.liveFrames(of: Array(visible))
        let listChanged = visible != session.visibleWindows
        let sliding = !listChanged
            && now >= (motionGraceEnd ?? now)
            && Self.displacement(from: tracker.liveFrames, to: frames) > Self.desktopMotionThreshold
        guard listChanged || sliding else { return false }
        log.info("desktop changing: \(listChanged ? "window list" : "thumbnails sliding", privacy: .public)")
        desktopChange = DesktopChange(visible: visible, frames: frames, stableSince: now, detectedAt: now)
        dependencies.presenter.dismiss()
        presented = nil
        startRefreshing()
        return true
    }

    private func settleDesktopChange(in session: NavigationSession) {
        guard var change = desktopChange else { return }
        let now = dependencies.clock.now
        let visible = dependencies.windows.visibleWindowIDs(on: session.display)
        let frames = dependencies.windows.liveFrames(of: Array(visible))
        if visible != change.visible || Self.displacement(from: change.frames, to: frames) > Self.desktopMotionThreshold {
            change.stableSince = now
        }
        change.visible = visible
        change.frames = frames
        desktopChange = change
        let timedOut = now - change.detectedAt >= Self.desktopChangeTimeout
        guard now - change.stableSince >= Self.desktopStableTime || timedOut else { return }
        let unchanged = visible == session.visibleWindows
        var windows: [MissionWindow] = []
        if !unchanged {
            windows = dependencies.windows.snapshot().filter { $0.displayID == session.display }
            // Apps list the windows of the new desktop only ~0.9 s after the switch; keep asking for a while.
            if windows.count < visible.count, now - change.detectedAt < Self.desktopMatchTimeout {
                change.stableSince = now
                desktopChange = change
                return
            }
        }
        desktopChange = nil
        let waited = Int((now - change.detectedAt) / .milliseconds(1))
        log.info("desktop settled after \(waited) ms: \(unchanged ? "same windows" : "\(windows.count) of \(visible.count) visible windows", privacy: .public) · \(self.pendingActions.count) keys waiting")
        if unchanged {
            tracker.update(liveFrames: frames)
            dependencies.presenter.prepare(for: Array(session.windows.values))
            render()
        } else {
            rebuildForCurrentDesktop(from: session, windows: windows, visible: visible)
        }
        let actions = pendingActions
        pendingActions = []
        for action in actions {
            perform(action)
        }
    }

    private func rebuildForCurrentDesktop(from previous: NavigationSession, windows: [MissionWindow], visible: Set<CGWindowID>) {
        let kept = previous.engine.selectedID.flatMap { id in windows.firstIndex { $0.id == id } }
        var session = NavigationSession(windows: windows, display: previous.display, startedAt: previous.startedAt, initialIndex: kept ?? 0)
        session.thumbnails = dependencies.thumbnails.thumbnails(for: windows)
        session.visibleWindows = visible
        startTracking(windows, skipsOpeningDelay: true)
        motionGraceEnd = dependencies.clock.now + Self.openingSettleTime
        presented = nil
        refreshTick = 0
        state = .navigating(session)
        dependencies.presenter.prepare(for: windows)
        render()
        onEvent?(.desktopChanged(windows: windows.count))
        startRefreshing()
    }

    private func startTracking(_ windows: [MissionWindow], skipsOpeningDelay: Bool = false) {
        let ids = windows.map(\.id)
        tracker.begin(
            realSizes: ids.reduce(into: [:]) { result, id in result[id] = dependencies.windows.realSize(of: id) },
            liveFrames: dependencies.windows.liveFrames(of: ids),
            openedAt: dependencies.clock.now,
            pointer: dependencies.pointer.location,
            skipsOpeningDelay: skipsOpeningDelay || dependencies.reducesMotion()
        )
    }

    private func finishSession() {
        let wasActive = state.session != nil
        stopSessionWork()
        tracker.reset()
        state = .idle
        if wasActive {
            onEvent?(.closed)
        }
    }

    private func activate(_ session: NavigationSession) {
        guard let window = session.selected else { return }
        state = .activating(session, target: window.id)
        stopSessionWork()
        let thumbnail = session.thumbnails[window.id]
        let activator = dependencies.activator
        Task { [weak self] in
            let result = await activator.activate(window, thumbnail: thumbnail)
            self?.onEvent?(.activated(window, result))
        }
    }

    private func move(_ session: NavigationSession, toDesktop number: Int) {
        guard let window = session.selected else { return }
        state = .movingWindow(session, target: window.id, desktop: number)
        dependencies.presenter.dismiss()
        presented = nil
        let mover = dependencies.mover
        Task { [weak self] in
            let result = await mover.move(window, toDesktop: number)
            self?.finishMove(window, toDesktop: number, result: result)
        }
    }

    private func finishMove(_ window: MissionWindow, toDesktop number: Int, result: SpaceMoveResult) {
        guard case .movingWindow(var session, let target, _) = state, target == window.id else { return }
        if result.moved {
            session.remove(window.id)
            session.visibleWindows = dependencies.windows.visibleWindowIDs(on: session.display)
        }
        motionGraceEnd = dependencies.clock.now + Self.openingSettleTime
        state = .navigating(session)
        tracker.reclaim(pointer: dependencies.pointer.location)
        dependencies.presenter.prepare(for: Array(session.windows.values))
        render()
        if case .failed(let failure, _) = result {
            dependencies.presenter.showNotice(Self.notice(for: failure, window: window, desktop: number))
        }
        onEvent?(.moved(window, desktop: number, result))
    }

    private static func notice(for failure: SpaceMoveFailure, window: MissionWindow, desktop number: Int) -> String {
        switch failure {
        case .onAllDesktops:
            "\(window.appName) is on all desktops. Change it in the Dock: Options → Assign To → None"
        case .invalidDesktop:
            "macOS allows up to \(SpaceMover.maximumDesktops) desktops"
        case .desktopNotCreated:
            "Couldn't create Desktop \(number)"
        case .noThumbnail, .noSpacesBar, .dropRejected:
            "Couldn't move the window to Desktop \(number)"
        }
    }

    private func stopSessionWork() {
        refreshTask?.cancel()
        refreshTask = nil
        desktopChange = nil
        motionGraceEnd = nil
        pendingActions = []
        dependencies.pointer.stop()
        dependencies.keyboard.setMode(.off)
        dependencies.presenter.dismiss()
        presented = nil
    }

    private func startRefreshing() {
        refreshTask?.cancel()
        let clock = dependencies.clock
        refreshTask = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                await clock.sleep(for: self?.refreshInterval(tick: tick) ?? .milliseconds(150))
                tick += 1
                guard let self, !Task.isCancelled else { return }
                self.refresh()
            }
        }
    }

    private static func displacement(from old: [CGWindowID: CGRect], to new: [CGWindowID: CGRect]) -> CGFloat {
        var largest: CGFloat = 0
        for (id, frame) in new {
            guard let previous = old[id] else { continue }
            let dx: CGFloat = abs(previous.minX - frame.minX)
            let dy: CGFloat = abs(previous.minY - frame.minY)
            let dw: CGFloat = abs(previous.width - frame.width)
            let dh: CGFloat = abs(previous.height - frame.height)
            largest = max(largest, dx, dy, dw, dh)
        }
        return largest
    }

    private func refreshInterval(tick: Int) -> Duration {
        desktopChange != nil ? .milliseconds(30) : .milliseconds(tick < 15 ? 60 : 150)
    }

    private func render() {
        guard desktopChange == nil,
              case .navigating(let session) = state,
              let presentation = tracker.presentation(for: session, now: dependencies.clock.now),
              presentation != presented
        else { return }
        presented = presentation
        dependencies.presenter.present(presentation)
    }
}
