import AppKit
import QuartzCore

@MainActor
public final class SelectionOverlay {
    private static let hudSize = NSSize(width: 640, height: 56)
    private static let ringGap: CGFloat = 3
    private static let ringWidth: CGFloat = 4

    private final class Card {
        let id: CGWindowID
        let screenIndex: Int
        let container = CALayer()
        let image = CALayer()
        let ring = CAShapeLayer()
        var hasImage = false
        var lift: CGFloat = 1

        init(id: CGWindowID, screenIndex: Int) {
            self.id = id
            self.screenIndex = screenIndex
        }
    }

    private var panels: [NSPanel] = []
    private var current: Card?
    private let hudPanel: NSPanel
    private let hudLabel: NSTextField

    public init() {
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

    public func showSelection(id: CGWindowID, globalRect: CGRect, cornerRadius: CGFloat, image: CGImage?, lift: CGFloat, animated: Bool) {
        rebuildPanelsIfNeeded()
        let target = appKitRect(fromGlobal: globalRect)
        let screens = NSScreen.screens
        guard let index = screens.indices.max(by: { overlap(screens[$0].frame, target) < overlap(screens[$1].frame, target) }),
              index < panels.count,
              overlap(screens[index].frame, target) > 0
        else {
            hideSelection(animated: false)
            return
        }
        let local = target.offsetBy(dx: -screens[index].frame.minX, dy: -screens[index].frame.minY)
        if let card = current, card.id == id, card.screenIndex == index {
            layout(card, in: local, cornerRadius: cornerRadius)
            if let image, !card.hasImage {
                setImage(image, on: card)
            }
            if card.hasImage, card.lift != lift {
                setLift(lift, on: card, animated: animated)
            }
            return
        }
        retire(current, animated: animated)
        let card = makeCard(id: id, screenIndex: index, scale: screens[index].backingScaleFactor)
        layout(card, in: local, cornerRadius: cornerRadius)
        panels[index].contentView?.layer?.addSublayer(card.container)
        panels[index].orderFrontRegardless()
        current = card
        if let image {
            setImage(image, on: card)
            setLift(lift, on: card, animated: animated)
        } else if animated {
            enter(card)
        }
    }

    public func hideSelection(animated: Bool) {
        retire(current, animated: animated)
        current = nil
    }

    public func showHighlight(globalRect: CGRect?, cornerRadius: CGFloat? = nil) {
        guard let globalRect else {
            hideSelection(animated: false)
            return
        }
        let radius = cornerRadius ?? min(max(min(globalRect.width, globalRect.height) * 0.045, 8), 18)
        showSelection(id: 0, globalRect: globalRect, cornerRadius: radius, image: nil, lift: 1, animated: false)
    }

    public func showHUD(text: String, near globalRect: CGRect?) {
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

    public func panelDiagnostics() -> [String] {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return panels.enumerated().map { index, panel in
            let screen = index < NSScreen.screens.count ? NSStringFromRect(NSScreen.screens[index].frame) : "?"
            var drawn = "none"
            if let card = current, card.screenIndex == index {
                let size = card.container.bounds.size
                let local = CGRect(x: card.container.position.x - size.width / 2, y: card.container.position.y - size.height / 2, width: size.width, height: size.height)
                let global = ScreenGeometry.globalRect(fromAppKit: local.offsetBy(dx: panel.frame.minX, dy: panel.frame.minY), primaryScreenHeight: primaryHeight)
                drawn = "(\(Int(global.minX)),\(Int(global.minY)) \(Int(global.width))x\(Int(global.height)))"
            }
            return "screen \(screen) · panel \(NSStringFromRect(panel.frame)) · visible \(panel.isVisible) · drawn box in global coordinates \(drawn)"
        }
    }

    public var visibleWindowNumbers: [Int] {
        ([hudPanel] + panels).filter(\.isVisible).map(\.windowNumber)
    }

    public func hide() {
        current = nil
        for panel in panels {
            panel.contentView?.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
            panel.orderOut(nil)
        }
        hudPanel.orderOut(nil)
    }

    private func makeCard(id: CGWindowID, screenIndex: Int, scale: CGFloat) -> Card {
        let card = Card(id: id, screenIndex: screenIndex)
        card.container.shadowColor = NSColor.black.cgColor
        card.container.shadowOpacity = 0
        card.container.shadowRadius = 22
        card.container.shadowOffset = CGSize(width: 0, height: -10)
        card.image.contentsGravity = .resize
        card.image.masksToBounds = true
        card.image.isHidden = true
        card.ring.fillColor = nil
        card.ring.strokeColor = NSColor.controlAccentColor.cgColor
        card.ring.lineWidth = Self.ringWidth
        card.ring.contentsScale = scale
        card.ring.shadowColor = NSColor.black.cgColor
        card.ring.shadowOpacity = 0.4
        card.ring.shadowRadius = 8
        card.ring.shadowOffset = .zero
        card.container.addSublayer(card.image)
        card.container.addSublayer(card.ring)
        return card
    }

    private func layout(_ card: Card, in local: CGRect, cornerRadius: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let bounds = CGRect(origin: .zero, size: local.size)
        card.container.bounds = bounds
        card.container.position = CGPoint(x: local.midX, y: local.midY)
        card.container.shadowPath = CGPath(roundedRect: bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        card.image.frame = bounds
        card.image.cornerRadius = cornerRadius
        card.ring.frame = bounds
        let ringRadius = cornerRadius + Self.ringGap
        card.ring.path = CGPath(
            roundedRect: bounds.insetBy(dx: -Self.ringGap, dy: -Self.ringGap),
            cornerWidth: ringRadius,
            cornerHeight: ringRadius,
            transform: nil
        )
        CATransaction.commit()
    }

    private func setImage(_ image: CGImage, on card: Card) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        card.image.contents = image
        card.image.isHidden = false
        card.hasImage = true
        CATransaction.commit()
    }

    private func setLift(_ lift: CGFloat, on card: Card, animated: Bool) {
        let from = currentScale(of: card.container)
        let shadowFrom = card.container.presentation()?.shadowOpacity ?? card.container.shadowOpacity
        let shadowTo: Float = lift > 1 ? 0.45 : 0
        card.lift = lift
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        card.container.transform = CATransform3DMakeScale(lift, lift, 1)
        card.container.shadowOpacity = shadowTo
        CATransaction.commit()
        guard animated else { return }
        let spring = CASpringAnimation(perceptualDuration: 0.34, bounce: 0.18)
        spring.keyPath = "transform.scale"
        spring.fromValue = from
        spring.toValue = lift
        spring.duration = spring.settlingDuration
        card.container.add(spring, forKey: "lift")
        let shadow = CABasicAnimation(keyPath: "shadowOpacity")
        shadow.fromValue = shadowFrom
        shadow.toValue = shadowTo
        shadow.duration = 0.24
        shadow.timingFunction = CAMediaTimingFunction(name: .easeOut)
        card.container.add(shadow, forKey: "shadow")
    }

    private func enter(_ card: Card) {
        let spring = CASpringAnimation(perceptualDuration: 0.28, bounce: 0.12)
        spring.keyPath = "transform.scale"
        spring.fromValue = 1.035
        spring.toValue = 1
        spring.duration = spring.settlingDuration
        card.container.add(spring, forKey: "enter")
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = 0.14
        card.container.add(fade, forKey: "fade")
    }

    private func retire(_ card: Card?, animated: Bool) {
        guard let card else { return }
        guard animated else {
            card.container.removeFromSuperlayer()
            return
        }
        let fadeDelay = card.hasImage && card.lift > 1 ? 0.2 : 0
        if card.hasImage, card.lift > 1 {
            setLift(1, on: card, animated: true)
        }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.beginTime = CACurrentMediaTime() + fadeDelay
        fade.duration = 0.14
        fade.fillMode = .backwards
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        card.container.opacity = 0
        CATransaction.commit()
        card.container.add(fade, forKey: "retire")
        let layer = card.container
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int((fadeDelay + 0.2) * 1000)))
            layer.removeFromSuperlayer()
        }
    }

    private func currentScale(of layer: CALayer) -> CGFloat {
        let transform = layer.presentation()?.transform ?? layer.transform
        return CGFloat(transform.m11)
    }

    private func overlap(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let intersection = a.intersection(b)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }

    private func appKitRect(fromGlobal rect: CGRect) -> CGRect {
        ScreenGeometry.appKitRect(fromGlobal: rect, primaryScreenHeight: NSScreen.screens.first?.frame.height ?? 0)
    }

    private func rebuildPanelsIfNeeded() {
        let screens = NSScreen.screens
        let unchanged = panels.count == screens.count && zip(panels, screens).allSatisfy { $0.frame == $1.frame }
        guard !unchanged else { return }
        panels.forEach { $0.orderOut(nil) }
        current = nil
        panels = screens.map { screen in
            let panel = Self.makePanel(frame: screen.frame)
            let view = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.wantsLayer = true
            panel.contentView = view
            return panel
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
