import AppKit
import ApplicationServices

@MainActor
public final class LiveSpaceSystem: SpaceSystem {
    private static let displayIdentifier = "mc.display"
    private static let listIdentifier = "mc.spaces.list"
    private static let addIdentifier = "mc.spaces.add"

    private let source = CGEventSource(stateID: .hidSystemState)

    public init() {}

    public var pointerLocation: CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    public func isOnAllDesktops(_ window: MissionWindow) -> Bool {
        guard let bundleID = window.bundleID?.lowercased() else { return false }
        CFPreferencesAppSynchronize("com.apple.spaces" as CFString)
        let bindings = CFPreferencesCopyAppValue("app-bindings" as CFString, "com.apple.spaces" as CFString) as? [String: Any]
        return (bindings?[bundleID] as? String) == "AllSpaces"
    }

    public func thumbnailFrame(of window: MissionWindow) -> CGRect? {
        CGWindowSource.bounds(for: [window.id])[window.id]
    }

    public func spacesBar(containing point: CGPoint) -> SpacesBar? {
        guard let display = displayGroup(containing: point), let displayFrame = AX.frame(display),
              let list = descendant(of: display, identifier: Self.listIdentifier)
        else { return nil }
        // WindowManager reports each desktop's center as the origin of its frame.
        let centers = AX.elements(list, kAXChildrenAttribute).compactMap { AX.frame($0)?.origin }
        return SpacesBar(displayFrame: displayFrame, desktopCenters: centers)
    }

    public func addDesktop(containing point: CGPoint) {
        guard let display = displayGroup(containing: point), let add = descendant(of: display, identifier: Self.addIdentifier) else { return }
        _ = AX.perform(add, kAXPressAction)
    }

    public func isOnCurrentDesktop(_ window: MissionWindow) -> Bool {
        CGWindowSource.bounds(for: [window.id])[window.id] != nil
    }

    public func post(_ event: PointerEvent) {
        switch event {
        case .move(let point):
            postMouse(.mouseMoved, at: point)
        case .down(let point):
            postMouse(.leftMouseDown, at: point)
        case .drag(let point):
            postMouse(.leftMouseDragged, at: point)
        case .up(let point):
            postMouse(.leftMouseUp, at: point)
        case .warp(let point):
            CGWarpMouseCursorPosition(point)
        }
    }

    private func postMouse(_ type: CGEventType, at point: CGPoint) {
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left) else { return }
        event.flags = []
        event.post(tap: .cghidEventTap)
    }

    private func displayGroup(containing point: CGPoint) -> AXUIElement? {
        guard let pid = MissionControlAccessibility.windowManagerPID else { return nil }
        return AX.elements(AX.application(pid), kAXChildrenAttribute).first { element in
            AX.string(element, "AXIdentifier") == Self.displayIdentifier && (AX.frame(element)?.contains(point) ?? false)
        }
    }

    private func descendant(of root: AXUIElement, identifier: String, depth: Int = 0) -> AXUIElement? {
        if AX.string(root, "AXIdentifier") == identifier { return root }
        guard depth < 4 else { return nil }
        for child in AX.elements(root, kAXChildrenAttribute) {
            if let found = descendant(of: child, identifier: identifier, depth: depth + 1) { return found }
        }
        return nil
    }
}
