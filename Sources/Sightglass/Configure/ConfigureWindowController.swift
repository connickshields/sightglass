import AppKit
import SwiftUI

/// Hosts the Configure window for one watch.
@MainActor
final class ConfigureWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let onClose: () -> Void

    init(watch: Watch, onClose: @escaping () -> Void) {
        self.onClose = onClose
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init()
        let hosting = NSHostingController(rootView: ConfigureView(watch: watch) { [weak window] in window?.title = $0 })
        hosting.sizingOptions = []
        window.contentViewController = hosting
        window.setContentSize(NSSize(width: 780, height: 520))
        window.minSize = NSSize(width: 640, height: 400)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
    }

    func show() {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window.close()
    }

    func windowWillClose(_ notification: Notification) {
        // Let the close finish before the owner releases us.
        let onClose = onClose
        DispatchQueue.main.async { onClose() }
    }
}
