import AppKit
import SightglassCore

/// Asks the user for a file to watch.
@MainActor
enum FileChooser {
    /// The chosen file, or nil if the user cancelled or it couldn't be found.
    static func choose() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a JSON or NDJSON file to watch"
        let tracker = SelectionTracker()
        panel.delegate = tracker
        guard panel.runModal() == .OK else { return nil }
        if let url = panel.url ?? tracker.selection { return url }

        // The panel follows the chosen file by its identity, not its path. A
        // job that replaces the file (temp file, then rename) can leave the
        // panel with nothing to return, but it still knows the folder.
        guard let directory = panel.directoryURL else {
            warn("Sightglass couldn't open that file", "Try choosing it again.")
            return nil
        }
        return chooseAgain(in: directory)
    }

    /// Lists the folder by path and asks which file the user meant.
    private static func chooseAgain(in directory: URL) -> URL? {
        let folder = FileManager.default.displayName(atPath: directory.path)
        let files: [URL]
        do {
            files = try ChoosableFiles.list(in: directory)
        } catch {
            warn("Sightglass can't see the files in “\(folder)”",
                 "\(error.localizedDescription)\n\nIf the folder is in Desktop, Documents, or Downloads, allow Sightglass in System Settings → Privacy & Security → Files & Folders, then try again.")
            return nil
        }
        guard !files.isEmpty else {
            warn("There are no files in “\(folder)”", "Try choosing the file again.")
            return nil
        }

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 300, height: 26), pullsDown: false)
        popup.addItems(withTitles: files.map(\.lastPathComponent))
        popup.selectItem(at: 0)  // newest first: most likely the file that just got replaced
        let alert = NSAlert()
        alert.messageText = "Which file in “\(folder)” did you mean?"
        alert.informativeText = "The file changed while you were choosing it, so the Open panel lost track of it."
        alert.accessoryView = popup
        alert.addButton(withTitle: "Watch")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return files[popup.indexOfSelectedItem]
    }

    /// Opens the file once. For a file in Desktop, Documents, or Downloads,
    /// this is when macOS asks for access, and the call waits for the answer,
    /// so windows opened afterwards aren't left behind the prompt. Warns if the
    /// file can't be read.
    static func checkAccess(to url: URL) {
        let descriptor = open(url.path, O_RDONLY | O_NONBLOCK)  // O_NONBLOCK: a FIFO would wait for a writer
        guard descriptor < 0 else {
            close(descriptor)
            return
        }
        let code = errno
        guard code == EPERM || code == EACCES else { return }
        warn("Sightglass can't read “\(url.lastPathComponent)”",
             "If it's in Desktop, Documents, or Downloads, allow Sightglass in System Settings → Privacy & Security → Files & Folders.")
    }

    private static func warn(_ message: String, _ detail: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = detail
        alert.runModal()
    }
}

/// Remembers the panel's current selection while it can still be resolved.
@MainActor
private final class SelectionTracker: NSObject, NSOpenSavePanelDelegate {
    private(set) var selection: URL?

    func panelSelectionDidChange(_ sender: Any?) {
        // nil when the selected file has already been replaced.
        selection = (sender as? NSOpenPanel)?.url
    }
}
