import AppKit
import SightglassCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var manager: WatchManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.make()
        // SIGHTGLASS_CONFIG lets `make run-demo` use a throwaway config.
        let url = ProcessInfo.processInfo.environment["SIGHTGLASS_CONFIG"]
            .map { URL(fileURLWithPath: $0) } ?? ConfigStore.defaultURL
        let manager = WatchManager(store: ConfigStore(url: url))
        manager.start()
        self.manager = manager
    }
}
