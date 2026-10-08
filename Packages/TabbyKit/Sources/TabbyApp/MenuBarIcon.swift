import AppKit

@MainActor
enum MenuBarIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 16), flipped: false) { _ in
            NSColor.black.setStroke()
            let window = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 1.5, width: 15, height: 13), xRadius: 3.5, yRadius: 3.5)
            window.lineWidth = 1.5
            window.stroke()
            let chevron = NSBezierPath()
            chevron.move(to: NSPoint(x: 7.4, y: 11.2))
            chevron.line(to: NSPoint(x: 10.8, y: 8))
            chevron.line(to: NSPoint(x: 7.4, y: 4.8))
            chevron.lineWidth = 1.8
            chevron.lineCapStyle = .round
            chevron.lineJoinStyle = .round
            chevron.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Tabby"
        return image
    }()
}
