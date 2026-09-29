import Foundation

/// Loads and saves the watch list as pretty-printed JSON.
public struct ConfigStore: Sendable {
    public struct LoadResult: Equatable, Sendable {
        public var watches: [WatchConfig]
        /// Set when an unreadable file was moved aside.
        public var backupURL: URL?
    }

    private struct File: Codable {
        var version: Int
        var watches: [WatchConfig]
    }

    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// `~/Library/Application Support/Sightglass/config.json`
    public static var defaultURL: URL {
        URL.applicationSupportDirectory.appending(path: "Sightglass/config.json")
    }

    /// Reads the config. A file that can't be read or decoded is renamed to
    /// `config.json.bak-<yyyyMMdd-HHmmss>` and an empty list is returned.
    public func load(now: Date = Date()) -> LoadResult {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return LoadResult(watches: [], backupURL: nil)
        }
        do {
            let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
            let watches = file.watches.map { watch in
                var watch = watch
                watch.path = (watch.path as NSString).expandingTildeInPath
                return watch
            }
            return LoadResult(watches: watches, backupURL: nil)
        } catch {
            let backup = url.deletingLastPathComponent()
                .appending(path: "\(url.lastPathComponent).bak-\(Self.stamp(now))")
            try? FileManager.default.moveItem(at: url, to: backup)
            return LoadResult(watches: [], backupURL: backup)
        }
    }

    public func save(_ watches: [WatchConfig]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(File(version: 1, watches: watches)).write(to: url, options: .atomic)
    }

    static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}
