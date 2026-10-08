import CoreGraphics

struct HighlightTracker {
    static let openingDelay: Duration = .milliseconds(320)
    static let pointerSlack: CGFloat = 40

    private(set) var liveFrames: [CGWindowID: CGRect] = [:]
    private(set) var pointerTookOver = false
    private var realSizes: [CGWindowID: CGSize] = [:]
    private var openedAt: ContinuousClock.Instant?
    private var skipsOpeningDelay = false
    private var pointerAnchor: CGPoint?

    mutating func begin(
        realSizes: [CGWindowID: CGSize],
        liveFrames: [CGWindowID: CGRect],
        openedAt: ContinuousClock.Instant,
        pointer: CGPoint,
        skipsOpeningDelay: Bool
    ) {
        self.realSizes = realSizes
        self.liveFrames = liveFrames
        self.openedAt = openedAt
        self.skipsOpeningDelay = skipsOpeningDelay
        pointerAnchor = pointer
        pointerTookOver = false
    }

    mutating func update(liveFrames: [CGWindowID: CGRect]) {
        self.liveFrames = liveFrames
    }

    mutating func pointerMoved(to location: CGPoint) -> Bool {
        guard !pointerTookOver, let pointerAnchor else { return false }
        guard hypot(location.x - pointerAnchor.x, location.y - pointerAnchor.y) > Self.pointerSlack else { return false }
        pointerTookOver = true
        return true
    }

    mutating func reclaim(pointer: CGPoint) {
        pointerTookOver = false
        pointerAnchor = pointer
    }

    mutating func reset() {
        self = HighlightTracker()
    }

    func presentation(for session: NavigationSession, now: ContinuousClock.Instant) -> SelectionPresentation? {
        let engine = session.engine
        guard let id = engine.selectedID, let index = engine.selectedIndex, let window = session.windows[id] else { return nil }
        let frame = liveFrames[id]
        let ready = skipsOpeningDelay || openedAt.map { now - $0 >= Self.openingDelay } ?? true
        let scale = frame.map { $0.width / max(realSizes[id]?.width ?? $0.width, 1) } ?? 1
        let title = window.title.map { " — \($0)" } ?? ""
        let count = engine.windowIDs.count
        let neighbors = Set([(index + 1) % count, (index - 1 + count) % count]).subtracting([index])
        return SelectionPresentation(
            windowID: id,
            label: "\(window.appName)\(title)  ·  \(index + 1)/\(count)",
            thumbnailFrame: frame,
            fallbackFrame: window.frame,
            cornerRadius: min(max(20 * scale, 8), 44),
            isHighlighted: frame != nil && ready && !pointerTookOver,
            neighborFrames: neighbors.reduce(into: [:]) { result, neighbor in
                let neighborID = engine.windowIDs[neighbor]
                result[neighborID] = liveFrames[neighborID]
            }
        )
    }
}
