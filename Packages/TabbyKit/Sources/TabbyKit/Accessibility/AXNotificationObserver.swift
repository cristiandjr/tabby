import ApplicationServices
import Foundation

@MainActor
public final class AXNotificationObserver {
    public var onNotification: (@MainActor (String, AXUIElement, ContinuousClock.Instant) -> Void)?

    private var observer: AXObserver?
    private var element: AXUIElement?
    private var registered: [String] = []

    public init() {}

    @discardableResult
    public func start(pid: pid_t, notifications: [String]) -> [String: String] {
        stop()
        var created: AXObserver?
        let status = AXObserverCreate(pid, { _, element, notification, refcon in
            guard let refcon else { return }
            let name = notification as String
            let instance = Unmanaged<AXNotificationObserver>.fromOpaque(refcon).takeUnretainedValue()
            MainActor.assumeIsolated {
                instance.receive(name, element: element)
            }
        }, &created)
        guard status == .success, let created else { return ["observer": status.name] }
        let application = AX.application(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        var results: [String: String] = [:]
        for notification in notifications {
            let result = AXObserverAddNotification(created, application, notification as CFString, refcon)
            results[notification] = result.name
            if result == .success { registered.append(notification) }
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        observer = created
        element = application
        return results
    }

    public func stop() {
        if let observer, let element {
            for notification in registered {
                AXObserverRemoveNotification(observer, element, notification as CFString)
            }
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        element = nil
        registered = []
    }

    private func receive(_ name: String, element: AXUIElement) {
        onNotification?(name, element, ContinuousClock().now)
    }
}
