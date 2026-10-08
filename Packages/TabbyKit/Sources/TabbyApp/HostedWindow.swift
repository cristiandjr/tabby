import AppKit
import SwiftUI

@MainActor
final class HostedWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var onClose: (() -> Void)?

    func show<Content: View>(title: String, transparentTitleBar: Bool = false, onClose: (() -> Void)? = nil, content: () -> Content) {
        self.onClose = onClose
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: content()))
            window.title = title
            window.styleMask = transparentTitleBar ? [.titled, .closable, .fullSizeContentView] : [.titled, .closable]
            window.titlebarAppearsTransparent = transparentTitleBar
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }
        NSApplication.shared.activate()
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
        onClose = nil
        window = nil
    }
}
