import AppKit
import ApplicationServices

public enum ActivationStrategy: String, CaseIterable, Codable, Sendable {
    case dockThumbnail
    case accessibility
    case runningApplication
}

@MainActor
public enum WindowActivator {
    @discardableResult
    public static func pressThumbnail(_ element: AXUIElement) -> AXError {
        AX.perform(element, kAXPressAction)
    }

    public static func activateWithAccessibility(pid: pid_t, window: AXUIElement) -> [String: String] {
        let app = AX.application(pid)
        return [
            "frontmost": AX.set(app, kAXFrontmostAttribute, kCFBooleanTrue).name,
            "main": AX.set(window, kAXMainAttribute, kCFBooleanTrue).name,
            "raise": AX.perform(window, kAXRaiseAction).name,
        ]
    }

    public static func activateWithRunningApplication(pid: pid_t, window: AXUIElement?) -> [String: String] {
        let activated = NSRunningApplication(processIdentifier: pid)?.activate(options: []) ?? false
        var detail = ["activate": activated ? "true" : "false"]
        if let window {
            detail["raise"] = AX.perform(window, kAXRaiseAction).name
        }
        return detail
    }

    public static func focusedWindow() -> (pid: pid_t, windowID: CGWindowID?)? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let window = AX.element(AX.application(app.processIdentifier), kAXFocusedWindowAttribute)
        return (app.processIdentifier, window.flatMap(PrivateAXBridge.windowID(of:)))
    }

    public static func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags = []) {
        let source = CGEventSource(stateID: .hidSystemState)
        for isDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isDown) else { continue }
            event.flags = flags
            event.post(tap: .cghidEventTap)
        }
    }
}
