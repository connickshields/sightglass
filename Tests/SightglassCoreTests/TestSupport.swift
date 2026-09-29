import Foundation

/// A fresh, empty temporary directory.
func makeTempDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "sightglass-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

/// Polls `condition` every 20 ms until it's true or `timeout` passes.
func waitUntil(timeout: TimeInterval = 3, _ condition: @Sendable () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(20))
    }
    return condition()
}

/// Thread-safe list for collecting callbacks.
final class Recorder<Element: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [Element] = []

    func append(_ item: Element) { lock.withLock { items.append(item) } }
    var all: [Element] { lock.withLock { items } }
}

extension URL {
    /// Rewrites the file in place (same inode), creating it if needed.
    func overwrite(_ string: String) throws {
        let data = Data(string.utf8)
        guard FileManager.default.fileExists(atPath: path) else {
            FileManager.default.createFile(atPath: path, contents: data)
            return
        }
        let handle = try FileHandle(forWritingTo: self)
        defer { try? handle.close() }
        try handle.truncate(atOffset: 0)
        try handle.write(contentsOf: data)
    }

    func append(_ string: String) throws {
        let handle = try FileHandle(forWritingTo: self)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(string.utf8))
    }

    /// Writes a temp file and renames it over this one (new inode).
    func replaceAtomically(_ string: String) throws {
        try Data(string.utf8).write(to: self, options: .atomic)
    }
}
