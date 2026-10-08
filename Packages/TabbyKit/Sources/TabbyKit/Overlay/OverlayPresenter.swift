import AppKit

@MainActor
public final class OverlayPresenter: SelectionPresenting {
    public static let maximumLift: CGFloat = 0.06
    public static let maximumLiftPoints: CGFloat = 44
    private static let screenMargin: CGFloat = 6

    public var liftsSelection = true
    private let log = Log.logger("overlay")
    private let overlay = SelectionOverlay()
    private let snapshots = WindowSnapshotter()
    private var current: SelectionPresentation?
    private var lifts = false
    private var animates = true

    public init() {}

    public static var canCaptureWindows: Bool {
        WindowSnapshotter.hasPermission
    }

    public func prepare(for windows: [MissionWindow]) {
        current = nil
        animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let permission = WindowSnapshotter.hasPermission
        lifts = liftsSelection && animates && permission
        log.info("lift \(self.lifts ? "on" : "off", privacy: .public) · setting \(self.liftsSelection) · screen recording \(permission) · reduce motion \(!self.animates)")
        snapshots.reset()
        if lifts {
            snapshots.warmUp()
        }
    }

    public func present(_ presentation: SelectionPresentation) {
        current = presentation
        overlay.showHUD(text: presentation.label, near: presentation.thumbnailFrame ?? presentation.fallbackFrame)
        guard presentation.isHighlighted, let frame = presentation.thumbnailFrame else {
            overlay.hideSelection(animated: animates)
            return
        }
        let id = presentation.windowID
        let cached = lifts ? snapshots.cachedImage(for: id) : nil
        overlay.showSelection(
            id: id,
            globalRect: frame,
            cornerRadius: presentation.cornerRadius,
            image: cached,
            lift: lifts ? lift(for: frame) : 1,
            animated: animates
        )
        guard lifts else { return }
        if cached == nil {
            let size = pixelSize(for: frame)
            Task { [weak self] in
                guard let image = await self?.snapshots.image(for: id, size: size) else { return }
                self?.showLifted(id, image: image)
            }
        }
        for (neighbor, neighborFrame) in presentation.neighborFrames {
            snapshots.prefetch(neighbor, size: pixelSize(for: neighborFrame))
        }
    }

    public func dismiss() {
        current = nil
        overlay.hide()
        snapshots.reset()
    }

    private func showLifted(_ id: CGWindowID, image: CGImage) {
        guard let current, current.windowID == id, current.isHighlighted, let frame = current.thumbnailFrame else { return }
        overlay.showSelection(id: id, globalRect: frame, cornerRadius: current.cornerRadius, image: image, lift: lift(for: frame), animated: true)
    }

    private func lift(for frame: CGRect) -> CGFloat {
        var scale = 1 + min(Self.maximumLift, Self.maximumLiftPoints / max(frame.width, frame.height, 1))
        if let bounds = screenBounds(containing: frame)?.insetBy(dx: Self.screenMargin, dy: Self.screenMargin) {
            let horizontal = 2 * min(frame.midX - bounds.minX, bounds.maxX - frame.midX) / max(frame.width, 1)
            let vertical = 2 * min(frame.midY - bounds.minY, bounds.maxY - frame.midY) / max(frame.height, 1)
            scale = min(scale, horizontal, vertical)
        }
        return max(scale, 1)
    }

    private func pixelSize(for frame: CGRect) -> CGSize {
        let backing = screen(containing: frame)?.backingScaleFactor ?? 2
        let factor = backing * (1 + Self.maximumLift)
        return CGSize(width: frame.width * factor, height: frame.height * factor)
    }

    private func screen(containing frame: CGRect) -> NSScreen? {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let target = ScreenGeometry.appKitRect(fromGlobal: frame, primaryScreenHeight: primaryHeight)
        return NSScreen.screens.first { $0.frame.contains(CGPoint(x: target.midX, y: target.midY)) }
    }

    private func screenBounds(containing frame: CGRect) -> CGRect? {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return screen(containing: frame).map { ScreenGeometry.globalRect(fromAppKit: $0.frame, primaryScreenHeight: primaryHeight) }
    }
}
