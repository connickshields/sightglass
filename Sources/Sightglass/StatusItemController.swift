import AppKit
import SwiftUI
import SightglassCore

struct StatusItemActions {
    var configure: (Watch) -> Void
    var reveal: (Watch) -> Void
    var remove: (Watch) -> Void
    var addFile: () -> Void
}

/// A hosting view that lets clicks fall through to the status item button.
final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// The menu bar item and dropdown for one watch.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let watch: Watch
    private let actions: StatusItemActions
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var detailView: NSHostingView<MenuDetailView>?

    init(watch: Watch, actions: StatusItemActions) {
        self.watch = watch
        self.actions = actions
        super.init()
        statusItem.autosaveName = "sightglass.\(watch.id.uuidString)"
        if let button = statusItem.button {
            let content = StatusItemView(watch: watch) { [weak self] width in
                self?.statusItem.length = ceil(width)
            }
            let hosting = PassthroughHostingView(rootView: content)
            hosting.frame = button.bounds
            hosting.autoresizingMask = [.width, .height]
            button.addSubview(hosting)
            button.setAccessibilityLabel(watch.config.name)
        }
        statusItem.menu = makeMenu()
    }

    func removeFromMenuBar() {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func menuWillOpen(_ menu: NSMenu) {
        if let detailView { detailView.frame.size = detailView.fittingSize }
    }

    /// Keeps the menu's header item as tall as its content while the menu is open.
    private func resizeDetail(toHeight height: CGFloat) {
        guard let detailView else { return }
        let height = ceil(height)
        guard abs(detailView.frame.height - height) > 0.5 else { return }
        detailView.frame.size = NSSize(width: detailView.frame.width, height: height)
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self

        let detail = NSMenuItem()
        let detailView = NSHostingView(rootView: MenuDetailView(watch: watch) { [weak self] height in
            self?.resizeDetail(toHeight: height)
        })
        detailView.frame.size = detailView.fittingSize
        detail.view = detailView
        self.detailView = detailView
        menu.addItem(detail)

        menu.addItem(.separator())
        menu.addItem(item("Configure…", #selector(configureWatch), key: ","))
        menu.addItem(item("Reveal in Finder", #selector(revealWatch)))
        menu.addItem(item("Remove", #selector(removeWatch)))
        menu.addItem(.separator())
        menu.addItem(item("Add File…", #selector(addFile), key: "o"))
        let quit = NSMenuItem(title: "Quit Sightglass", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
        return menu
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func configureWatch() { actions.configure(watch) }
    @objc private func revealWatch() { actions.reveal(watch) }
    @objc private func removeWatch() { actions.remove(watch) }
    @objc private func addFile() { actions.addFile() }
}
