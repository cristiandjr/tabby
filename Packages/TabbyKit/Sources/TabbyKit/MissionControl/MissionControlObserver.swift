import AppKit
import ApplicationServices

public enum MissionControlEvent: String, CaseIterable, Codable, Sendable {
    case showAllWindows = "AXExposeShowAllWindows"
    case showFrontWindows = "AXExposeShowFrontWindows"
    case showDesktop = "AXExposeShowDesktop"
    case exit = "AXExposeExit"
}

@MainActor
public final class MissionControlObserver {
    public var onEvent: (@MainActor (MissionControlEvent, ContinuousClock.Instant) -> Void)?
    public private(set) var dockPID: pid_t?

    private var observer: AXObserver?
    private var dockElement: AXUIElement?
    private var relaunchToken: NSObjectProtocol?

    public init() {}

    @discardableResult
    public func start() -> [MissionControlEvent: AXError]? {
        stop()
        guard let pid = DockAccessibility.pid else { return nil }
        var created: AXObserver?
        let status = AXObserverCreate(pid, { _, _, notification, refcon in
            guard let refcon else { return }
            let name = notification as String
            let instance = Unmanaged<MissionControlObserver>.fromOpaque(refcon).takeUnretainedValue()
            MainActor.assumeIsolated {
                instance.receive(name)
            }
        }, &created)
        guard status == .success, let created else { return nil }
        let element = AX.application(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        var results: [MissionControlEvent: AXError] = [:]
        for event in MissionControlEvent.allCases {
            results[event] = AXObserverAddNotification(created, element, event.rawValue as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        observer = created
        dockElement = element
        dockPID = pid
        watchDockRelaunch()
        return results
    }

    public func stop() {
        if let observer, let dockElement {
            for event in MissionControlEvent.allCases {
                AXObserverRemoveNotification(observer, dockElement, event.rawValue as CFString)
            }
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        dockElement = nil
        dockPID = nil
    }

    private func receive(_ name: String) {
        guard let event = MissionControlEvent(rawValue: name) else { return }
        onEvent?(event, ContinuousClock().now)
    }

    private func watchDockRelaunch() {
        guard relaunchToken == nil else { return }
        relaunchToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard app?.bundleIdentifier == DockAccessibility.bundleID else { return }
            MainActor.assumeIsolated {
                _ = self?.start()
            }
        }
    }
}
