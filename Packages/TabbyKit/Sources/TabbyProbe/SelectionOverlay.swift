import AppKit
import QuartzCore
import TabbyKit

@MainActor
final class SelectionOverlay {
    private static let hudSize = NSSize(width: 640, height: 56)

    private var highlightPanels: [NSPanel] = []
    private var highlightLayers: [CAShapeLayer] = []
    private let hudPanel: NSPanel
    private let hudLabel: NSTextField

    init() {
        let size = Self.hudSize
        let panel = Self.makePanel(frame: NSRect(origin: .zero, size: size))
        let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 16
        background.layer?.masksToBounds = true
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.lineBreakMode = .byTruncatingMiddle
        label.frame = NSRect(x: 18, y: 17, width: size.width - 36, height: 22)
        background.addSubview(label)
        panel.contentView = background
        hudPanel = panel
        hudLabel = label
    }

    func showHighlight(globalRect: CGRect?) {
        guard let globalRect else {
            highlightPanels.forEach { $0.orderOut(nil) }
            return
        }
        rebuildHighlightPanelsIfNeeded()
        let target = appKitRect(fromGlobal: globalRect)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, screen) in NSScreen.screens.enumerated() where index < highlightPanels.count {
            let panel = highlightPanels[index]
            if screen.frame.intersects(target) {
                let local = target.offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY).insetBy(dx: -6, dy: -6)
                highlightLayers[index].path = CGPath(roundedRect: local, cornerWidth: 14, cornerHeight: 14, transform: nil)
                panel.orderFrontRegardless()
            } else {
                panel.orderOut(nil)
            }
        }
        CATransaction.commit()
    }

    func showHUD(text: String, near globalRect: CGRect?) {
        let screen = globalRect.flatMap { rect in
            NSScreen.screens.first { $0.frame.intersects(appKitRect(fromGlobal: rect)) }
        } ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let size = Self.hudSize
        let frame = NSRect(x: screen.frame.midX - size.width / 2, y: screen.frame.minY + 90, width: size.width, height: size.height)
        hudPanel.setFrame(frame, display: true)
        hudLabel.stringValue = text
        hudPanel.orderFrontRegardless()
    }

    func hide() {
        highlightPanels.forEach { $0.orderOut(nil) }
        hudPanel.orderOut(nil)
    }

    private func appKitRect(fromGlobal rect: CGRect) -> CGRect {
        ScreenGeometry.appKitRect(fromGlobal: rect, primaryScreenHeight: NSScreen.screens.first?.frame.height ?? 0)
    }

    private func rebuildHighlightPanelsIfNeeded() {
        let screens = NSScreen.screens
        let unchanged = highlightPanels.count == screens.count
            && zip(highlightPanels, screens).allSatisfy { $0.frame == $1.frame }
        guard !unchanged else { return }
        highlightPanels.forEach { $0.orderOut(nil) }
        highlightPanels = []
        highlightLayers = []
        for screen in screens {
            let panel = Self.makePanel(frame: screen.frame)
            let view = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.wantsLayer = true
            let shape = CAShapeLayer()
            shape.frame = view.bounds
            shape.fillColor = nil
            shape.strokeColor = NSColor.controlAccentColor.cgColor
            shape.lineWidth = 5
            shape.shadowColor = NSColor.black.cgColor
            shape.shadowOpacity = 0.4
            shape.shadowRadius = 8
            shape.shadowOffset = .zero
            view.layer?.addSublayer(shape)
            panel.contentView = view
            highlightPanels.append(panel)
            highlightLayers.append(shape)
        }
    }

    private static func makePanel(frame: NSRect) -> NSPanel {
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.assistiveTechHighWindow)))
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        return panel
    }
}
