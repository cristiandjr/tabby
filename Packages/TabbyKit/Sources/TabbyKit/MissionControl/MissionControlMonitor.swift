import AppKit
import ApplicationServices

@MainActor
public final class MissionControlMonitor {
    private var dockElement: AXUIElement?

    public init() {}

    public func isOpen() -> Bool? {
        guard let element = dockElement ?? connect() else { return nil }
        var count: CFIndex = 0
        guard AXUIElementGetAttributeValueCount(element, kAXChildrenAttribute as CFString, &count) == .success else {
            dockElement = nil
            return nil
        }
        guard count > 1 else { return false }
        let signature = AX.elements(element, kAXChildrenAttribute).map { child in
            (AX.string(child, kAXRoleAttribute) ?? "?") + (AX.string(child, "AXIdentifier").map { ":\($0)" } ?? "")
        }
        guard !signature.isEmpty else { return nil }
        return DockAccessibility.isMissionControlOpen(signature)
    }

    private func connect() -> AXUIElement? {
        guard let pid = DockAccessibility.pid else { return nil }
        let element = AX.application(pid)
        dockElement = element
        return element
    }
}
