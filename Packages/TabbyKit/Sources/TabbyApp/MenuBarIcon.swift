import AppKit

@MainActor
enum MenuBarIcon {
    static let image: NSImage = {
        let icon = NSApplication.shared.applicationIconImage ?? NSImage()
        let image = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            // The app icon leaves ~10% transparent margin per side; draw past the edges so the tile fills the item.
            let bleed = rect.width * 0.122
            icon.draw(in: rect.insetBy(dx: -bleed, dy: -bleed))
            return true
        }
        image.accessibilityDescription = "Tabby"
        return image
    }()
}
