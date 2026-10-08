import CoreGraphics

public struct NavigationSession {
    public private(set) var engine: NavigationEngine
    public let windows: [CGWindowID: MissionWindow]
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
        case .activate:
            break
        }
    }
}

public enum SessionState {
    case idle
    case navigating(NavigationSession)
    case activating(NavigationSession, target: CGWindowID)

    public var session: NavigationSession? {
        switch self {
        case .idle:
            nil
        case .navigating(let session), .activating(let session, _):
            session
        }
    }

    public var isNavigating: Bool {
        if case .navigating = self { return true }
        return false
    }
}
