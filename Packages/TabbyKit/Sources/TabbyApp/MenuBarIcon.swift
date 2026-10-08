import AppKit

@MainActor
enum MenuBarIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 19, height: 16), flipped: false) { _ in
            draw()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Tabby"
        return image
    }()

    private static func draw() {
        guard let context = NSGraphicsContext.current else { return }
        let back = NSBezierPath(roundedRect: NSRect(x: 5.6, y: 4.2, width: 12.8, height: 11.2), xRadius: 3, yRadius: 3)
        let front = NSRect(x: 0.6, y: 0.6, width: 13.4, height: 11.6)
        let frontPath = NSBezierPath(roundedRect: front, xRadius: 3, yRadius: 3)
        let gap = NSBezierPath(roundedRect: front.insetBy(dx: -1.3, dy: -1.3), xRadius: 4.2, yRadius: 4.2)

        NSColor.black.withAlphaComponent(0.55).setFill()
        back.fill()
        context.compositingOperation = .destinationOut
        gap.fill()
        context.compositingOperation = .sourceOver
        NSColor.black.setFill()
        frontPath.fill()

        context.compositingOperation = .destinationOut
        for x in [3.0, 5.0, 7.0] {
            NSBezierPath(ovalIn: NSRect(x: x - 0.75, y: 9.2, width: 1.5, height: 1.5)).fill()
        }
        let chevron = NSBezierPath()
        chevron.move(to: NSPoint(x: 6.1, y: 7.6))
        chevron.line(to: NSPoint(x: 8.9, y: 5.2))
        chevron.line(to: NSPoint(x: 6.1, y: 2.8))
        chevron.lineWidth = 1.7
        chevron.lineCapStyle = .round
        chevron.lineJoinStyle = .round
        NSColor.black.setStroke()
        chevron.stroke()
        context.compositingOperation = .sourceOver
    }
}
