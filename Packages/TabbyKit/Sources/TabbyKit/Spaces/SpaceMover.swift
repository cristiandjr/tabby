import CoreGraphics

public enum SpaceMoveFailure: String, Equatable, Sendable {
    case invalidDesktop
    case onAllDesktops
    case noThumbnail
    case noSpacesBar
    case desktopNotCreated
    case dropRejected
}

public enum SpaceMoveResult: Equatable, Sendable {
    case moved(createdDesktops: Int)
    case failed(SpaceMoveFailure, createdDesktops: Int)

    public var moved: Bool {
        if case .moved = self { return true }
        return false
    }
}

public struct SpacesBar: Equatable, Sendable {
    public var displayFrame: CGRect
    public var desktopCenters: [CGPoint]

    public init(displayFrame: CGRect, desktopCenters: [CGPoint]) {
        self.displayFrame = displayFrame
        self.desktopCenters = desktopCenters
    }

    public var isExpanded: Bool {
        desktopCenters.allSatisfy { $0.y > displayFrame.minY }
    }

    public static func isDesktop(actions: [String], description: String?) -> Bool {
        actions.contains("AXRemoveDesktop") || !(description?.localizedCaseInsensitiveContains("full screen") ?? false)
    }
}

public enum PointerEvent: Equatable, Sendable {
    case move(CGPoint)
    case down(CGPoint)
    case drag(CGPoint)
    case up(CGPoint)
    case warp(CGPoint)
}

@MainActor
public protocol SpaceMoving: AnyObject {
    func move(_ window: MissionWindow, toDesktop number: Int) async -> SpaceMoveResult
}

@MainActor
public protocol SpaceSystem: AnyObject {
    var pointerLocation: CGPoint { get }
    func isOnAllDesktops(_ window: MissionWindow) -> Bool
    func thumbnailFrame(of window: MissionWindow) -> CGRect?
    func spacesBar(containing point: CGPoint) -> SpacesBar?
    func addDesktop(containing point: CGPoint)
    func isOnCurrentDesktop(_ window: MissionWindow) -> Bool
    func post(_ event: PointerEvent)
}

@MainActor
public final class SpaceMover: SpaceMoving {
    public static let maximumDesktops = 16

    public struct Timing: Sendable {
        public var desktopCreation: Duration = .seconds(1)
        public var barExpansion: Duration = .milliseconds(700)
        public var hover: Duration = .milliseconds(150)
        public var dropVerification: Duration = .milliseconds(1200)
        public var step: Duration = .milliseconds(8)
        public var poll: Duration = .milliseconds(10)

        public init() {}
    }

    private let system: any SpaceSystem
    private let clock: any SessionClock
    private let timing: Timing

    public init(system: any SpaceSystem, clock: any SessionClock = SystemClock(), timing: Timing = Timing()) {
        self.system = system
        self.clock = clock
        self.timing = timing
    }

    public func move(_ window: MissionWindow, toDesktop number: Int) async -> SpaceMoveResult {
        guard (1...Self.maximumDesktops).contains(number) else { return .failed(.invalidDesktop, createdDesktops: 0) }
        guard !system.isOnAllDesktops(window) else { return .failed(.onAllDesktops, createdDesktops: 0) }
        guard let thumbnail = system.thumbnailFrame(of: window) else { return .failed(.noThumbnail, createdDesktops: 0) }
        let anchor = CGPoint(x: thumbnail.midX, y: thumbnail.midY)
        guard var bar = system.spacesBar(containing: anchor) else { return .failed(.noSpacesBar, createdDesktops: 0) }
        var created = 0
        while bar.desktopCenters.count < number {
            let before = bar.desktopCenters.count
            system.addDesktop(containing: anchor)
            let appeared = await waitUntil(timing.desktopCreation) {
                (system.spacesBar(containing: anchor)?.desktopCenters.count ?? 0) > before
            }
            guard appeared, let updated = system.spacesBar(containing: anchor) else {
                return .failed(.desktopNotCreated, createdDesktops: created)
            }
            bar = updated
            created += 1
        }
        let moved = await drag(window, from: anchor, toDesktop: number, display: bar.displayFrame)
        return moved ? .moved(createdDesktops: created) : .failed(.dropRejected, createdDesktops: created)
    }

    private func drag(_ window: MissionWindow, from anchor: CGPoint, toDesktop number: Int, display: CGRect) async -> Bool {
        let saved = system.pointerLocation
        system.post(.move(anchor))
        await clock.sleep(for: timing.step * 4)
        system.post(.down(anchor))
        await clock.sleep(for: timing.step * 8)
        let top = CGPoint(x: display.midX, y: display.minY + 60)
        await glide(from: anchor, to: top, steps: 12)
        _ = await waitUntil(timing.barExpansion) {
            system.spacesBar(containing: anchor)?.isExpanded ?? false
        }
        let centers = system.spacesBar(containing: anchor)?.desktopCenters ?? []
        var released = top
        var moved = false
        if centers.indices.contains(number - 1) {
            let target = centers[number - 1]
            await glide(from: top, to: target, steps: 8)
            await clock.sleep(for: timing.hover)
            released = target
        }
        system.post(.up(released))
        if released != top {
            moved = await waitUntil(timing.dropVerification) { !system.isOnCurrentDesktop(window) }
        }
        system.post(.warp(saved))
        return moved
    }

    private func glide(from start: CGPoint, to end: CGPoint, steps: Int) async {
        for step in 1...steps {
            let progress = CGFloat(step) / CGFloat(steps)
            system.post(.drag(CGPoint(x: start.x + (end.x - start.x) * progress, y: start.y + (end.y - start.y) * progress)))
            await clock.sleep(for: timing.step)
        }
    }

    private func waitUntil(_ timeout: Duration, _ condition: () -> Bool) async -> Bool {
        let deadline = clock.now + timeout
        while !condition() {
            guard clock.now < deadline else { return false }
            await clock.sleep(for: timing.poll)
        }
        return true
    }
}
