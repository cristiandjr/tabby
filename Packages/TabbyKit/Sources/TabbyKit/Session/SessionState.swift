import CoreGraphics

public struct NavigationSession {
    public private(set) var engine: NavigationEngine
    public private(set) var windows: [CGWindowID: MissionWindow]
    public internal(set) var thumbnails: [CGWindowID: MissionControlThumbnail] = [:]
    public let display: CGDirectDisplayID
    let startedAt: ContinuousClock.Instant
    var visibleWindows: Set<CGWindowID> = []

    init(windows: [MissionWindow], display: CGDirectDisplayID, startedAt: ContinuousClock.Instant, initialIndex: Int = 1) {
        engine = NavigationEngine(windowIDs: windows.map(\.id), initialIndex: initialIndex)
        self.windows = Dictionary(windows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.display = display
        self.startedAt = startedAt
    }

    public var selected: MissionWindow? {
        engine.selectedID.flatMap { windows[$0] }
    }

    mutating func move(_ action: SessionAction) {
        switch action {
        case .next:
            engine.next()
        case .previous:
            engine.previous()
        case .activate, .moveToDesktop:
            break
        }
    }

    mutating func remove(_ id: CGWindowID) {
        engine.update(windowIDs: engine.windowIDs.filter { $0 != id })
        windows[id] = nil
        thumbnails[id] = nil
    }
}

public enum SessionState {
    case idle
    case navigating(NavigationSession)
    case activating(NavigationSession, target: CGWindowID)
    case movingWindow(NavigationSession, target: CGWindowID, desktop: Int)

    public var session: NavigationSession? {
        switch self {
        case .idle:
            nil
        case .navigating(let session), .activating(let session, _), .movingWindow(let session, _, _):
            session
        }
    }

    public var isNavigating: Bool {
        if case .navigating = self { return true }
        return false
    }
}
