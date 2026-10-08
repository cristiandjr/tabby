import CoreGraphics

public struct NavigationSession {
    public private(set) var engine: NavigationEngine
    public private(set) var windows: [CGWindowID: MissionWindow]
    public internal(set) var thumbnails: [CGWindowID: MissionControlThumbnail] = [:]

    init(windows: [MissionWindow]) {
        engine = NavigationEngine(windowIDs: windows.map(\.id))
        self.windows = Dictionary(windows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
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
