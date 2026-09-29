import AppKit

/// The single Sightglass icon shown when nothing is being watched.
@MainActor
final class PlaceholderItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let onAddFile: () -> Void

    init(notice: String?, onAddFile: @escaping () -> Void) {
        self.onAddFile = onAddFile
        super.init()
        statusItem.button?.image = NSImage(systemSymbolName: "gauge.with.needle", accessibilityDescription: "Sightglass")

        let menu = NSMenu()
        if let notice {
            let item = NSMenuItem(title: notice, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            menu.addItem(.separator())
        }
        let add = NSMenuItem(title: "Add File…", action: #selector(addFile), keyEquivalent: "o")
        add.target = self
        menu.addItem(add)
        let quit = NSMenuItem(title: "Quit Sightglass", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
        statusItem.menu = menu
    }

    func removeFromMenuBar() {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    @objc private func addFile() { onAddFile() }
}
