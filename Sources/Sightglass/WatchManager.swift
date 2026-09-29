import AppKit
import SightglassCore

/// Owns the watches, their menu bar items, and the config file.
@MainActor
final class WatchManager {
    private let store: ConfigStore
    private(set) var watches: [Watch] = []
    private var items: [UUID: StatusItemController] = [:]
    private var placeholder: PlaceholderItemController?
    private var notice: String?
    private var clock: Timer?

    init(store: ConfigStore) {
        self.store = store
    }

    func start() {
        let result = store.load()
        if result.backupURL != nil { notice = "Settings could not be read; a backup was saved" }
        for config in result.watches { insert(config) }
        refreshPlaceholder()

        // .common so labels keep updating while a menu is open.
        let clock = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(clock, forMode: .common)
        self.clock = clock
    }

    func addFile() {
        NSApp.activate()
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a JSON or NDJSON file to watch"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        insert(WatchConfig(path: url.path))
        save()
        refreshPlaceholder()
    }

    func reveal(_ watch: Watch) {
        if FileManager.default.fileExists(atPath: watch.config.path) {
            NSWorkspace.shared.activateFileViewerSelecting([watch.config.url])
        } else {
            NSWorkspace.shared.open(watch.config.url.deletingLastPathComponent())
        }
    }

    func remove(_ watch: Watch) {
        watch.stop()
        items[watch.id]?.removeFromMenuBar()
        items[watch.id] = nil
        watches.removeAll { $0.id == watch.id }
        save()
        refreshPlaceholder()
    }

    @discardableResult
    private func insert(_ config: WatchConfig) -> Watch {
        let watch = Watch(config: config)
        watch.onConfigChange = { [weak self] _ in self?.save() }
        watches.append(watch)
        items[watch.id] = StatusItemController(watch: watch, actions: actions)
        watch.start()
        return watch
    }

    private var actions: StatusItemActions {
        StatusItemActions(
            reveal: { [weak self] in self?.reveal($0) },
            remove: { [weak self] in self?.remove($0) },
            addFile: { [weak self] in self?.addFile() }
        )
    }

    private func save() {
        do {
            try store.save(watches.map(\.config))
        } catch {
            NSLog("Sightglass: couldn't save settings: \(error)")
        }
    }

    private func refreshPlaceholder() {
        if watches.isEmpty {
            if placeholder == nil {
                placeholder = PlaceholderItemController(notice: notice) { [weak self] in self?.addFile() }
            }
        } else {
            placeholder?.removeFromMenuBar()
            placeholder = nil
        }
    }

    private func tick() {
        let now = Date()
        for watch in watches { watch.tick(now) }
    }
}
