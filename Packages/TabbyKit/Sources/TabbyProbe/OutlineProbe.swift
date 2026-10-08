import AppKit
import QuartzCore
import TabbyKit

@MainActor
enum OutlineProbe {
    static func run(hold: Duration = .seconds(5)) async -> Int32 {
        guard AX.isTrusted, SystemStatus.postEventAccess else {
            AX.requestTrust()
            say("Accessibility and post-event permissions are needed.")
            return 2
        }
        AX.setGlobalTimeout(0.3)
        if !isOpen {
            NSWorkspace.shared.openApplication(
                at: URL(fileURLWithPath: "/System/Applications/Mission Control.app"),
                configuration: NSWorkspace.OpenConfiguration(),
                completionHandler: nil
            )
        }
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(3)
        while clock.now < deadline, !isOpen {
            try? await Task.sleep(for: .milliseconds(10))
        }
        guard isOpen else {
            say("Mission Control did not open.")
            return 1
        }
        try? await Task.sleep(for: .milliseconds(700))
        if CommandLine.arguments.contains("--tree") {
            if let tree = MissionControlAccessibility.tree() {
                say(DockAccessibility.render(tree))
            }
            if let button = MissionControlAccessibility.thumbnails().first?.element {
                say("--- attributes of the first thumbnail")
                for name in AX.attributeNames(button).sorted() {
                    say("\(name) = \(AX.describe(AX.raw(button, name)))")
                }
                say("parameterized: \(AX.parameterizedAttributeNames(button).joined(separator: ", "))")
                say("actions: \(AX.actions(button).joined(separator: ", "))")
                say("_AXUIElementGetWindow: \(PrivateAXBridge.windowID(of: button).map(String.init) ?? "nil")")
            }
            let windows = WindowProvider().snapshot()
            say("--- on-screen windows")
            for window in windows {
                say("\(window.id) \(window.bundleID ?? "?") \"\(window.title ?? "")\" (\(Int(window.frame.minX)),\(Int(window.frame.minY)) \(Int(window.frame.width))x\(Int(window.frame.height)))")
            }
        }
        let thumbnails = MissionControlAccessibility.thumbnails()
        let live = CGWindowSource.bounds(for: WindowProvider().snapshot().map(\.id))
        let panels = drawOutlines(thumbnails.map(\.info.frame), color: .systemRed)
            + drawOutlines(Array(live.values), color: .systemGreen)
        for thumbnail in thumbnails {
            let frame = thumbnail.info.frame
            say("\(thumbnail.info.bundleID ?? "?") (\(Int(frame.minX)),\(Int(frame.minY)) \(Int(frame.width))x\(Int(frame.height)))")
        }
        say("outlines visible")
        try? await Task.sleep(for: hold)
        panels.forEach { $0.orderOut(nil) }
        if isOpen {
            WindowActivator.postKey(KeyCode.escape)
        }
        return 0
    }

    private static func drawOutlines(_ frames: [CGRect], color: NSColor) -> [NSPanel] {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return NSScreen.screens.map { screen in
            let panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.assistiveTechHighWindow)))
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            let view = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.wantsLayer = true
            let shape = CAShapeLayer()
            shape.frame = view.bounds
            shape.fillColor = nil
            shape.strokeColor = color.cgColor
            shape.lineWidth = 2
            let path = CGMutablePath()
            for frame in frames {
                let appKit = ScreenGeometry.appKitRect(fromGlobal: frame, primaryScreenHeight: primaryHeight)
                guard screen.frame.intersects(appKit) else { continue }
                path.addRect(appKit.offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY))
            }
            shape.path = path
            view.layer?.addSublayer(shape)
            panel.contentView = view
            panel.orderFrontRegardless()
            return panel
        }
    }

    private static var isOpen: Bool {
        DockAccessibility.isMissionControlOpen(DockAccessibility.topLevelSignature())
    }

    private static func say(_ text: String) {
        FileHandle.standardOutput.write(Data((text + "\n").utf8))
    }
}
