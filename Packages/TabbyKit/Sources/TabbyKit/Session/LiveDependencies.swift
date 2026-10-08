import AppKit
import ApplicationServices

extension MissionControlMonitor: MissionControlMonitoring {}

extension KeyboardInterceptor: KeyboardIntercepting {}

extension WindowProvider: WindowProviding {
    public func realSize(of id: CGWindowID) -> CGSize? {
        element(for: id).flatMap { AX.size($0, kAXSizeAttribute) }
    }

    public func liveFrames(of ids: [CGWindowID]) -> [CGWindowID: CGRect] {
        CGWindowSource.bounds(for: ids)
    }
}

@MainActor
public final class LiveThumbnailProvider: ThumbnailProviding {
    public init() {}

    public func thumbnails(for windows: [MissionWindow]) -> [CGWindowID: MissionControlThumbnail] {
        let found = MissionControlAccessibility.thumbnails()
        let matches = MissionControlAccessibility.match(windows: windows, thumbnails: found.map(\.info))
        return matches.reduce(into: [:]) { result, item in
            result[item.key] = found[item.value]
        }
    }
}

@MainActor
public final class LivePointerMonitor: PointerMonitoring {
    private var monitor: Any?

    public init() {}

    public var location: CGPoint {
        NSEvent.mouseLocation
    }

    public func start(onMove: @escaping @MainActor (CGPoint) -> Void) {
        stop()
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { _ in
            MainActor.assumeIsolated {
                onMove(NSEvent.mouseLocation)
            }
        }
    }

    public func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}

extension SessionDependencies {
    public static func live(presenter: (any SelectionPresenting)? = nil) -> SessionDependencies {
        let windows = WindowProvider()
        return SessionDependencies(
            monitor: MissionControlMonitor(),
            windows: windows,
            thumbnails: LiveThumbnailProvider(),
            activator: ActivationCoordinator(system: LiveActivationSystem(windows: windows)),
            mover: SpaceMover(system: LiveSpaceSystem()),
            presenter: presenter ?? OverlayPresenter(),
            keyboard: KeyboardInterceptor(),
            pointer: LivePointerMonitor(),
            clock: SystemClock(),
            reducesMotion: { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
        )
    }
}
