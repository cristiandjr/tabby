import AppKit

@MainActor
public final class SessionController {
    public enum Event {
        case opened(windows: Int)
        case selected(MissionWindow)
        case activated(MissionWindow, ActivationResult)
        case moved(MissionWindow, desktop: Int, SpaceMoveResult)
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

    private let dependencies: SessionDependencies
    private var detector = MissionControlDetector()
    private var tracker = HighlightTracker()
    private var presented: SelectionPresentation?
    private var refreshTick = 0
    private var pollTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?

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
        var session = NavigationSession(windows: windows)
        session.thumbnails = dependencies.thumbnails.thumbnails(for: windows)
        let ids = windows.map(\.id)
        tracker.begin(
            realSizes: ids.reduce(into: [:]) { result, id in result[id] = dependencies.windows.realSize(of: id) },
            liveFrames: dependencies.windows.liveFrames(of: ids),
            openedAt: dependencies.clock.now,
            pointer: dependencies.pointer.location,
            skipsOpeningDelay: dependencies.reducesMotion()
        )
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
        }
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
                await clock.sleep(for: .milliseconds(tick < 15 ? 60 : 150))
                tick += 1
                guard let self, !Task.isCancelled else { return }
                self.refresh()
            }
        }
    }

    private func render() {
        guard case .navigating(let session) = state,
              let presentation = tracker.presentation(for: session, now: dependencies.clock.now),
              presentation != presented
        else { return }
        presented = presentation
        dependencies.presenter.present(presentation)
    }
}
