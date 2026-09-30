import Foundation

/// The files a user can pick from in a folder, for when the Open panel loses
/// track of the file they chose. The panel follows a file by its identity, so
/// a job that replaces the file (write a temp file, rename it over the old
/// one) can leave it with nothing to return. Paths don't go stale that way.
public enum ChoosableFiles {
    /// Visible regular files in `directory`, most recently modified first.
    /// Paths start with `directory` as given, even if it has symlinks in it.
    public static func list(in directory: URL) throws -> [URL] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey]
        let files = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]
        ).compactMap { listed -> (url: URL, modified: Date)? in
            guard let values = try? listed.resourceValues(forKeys: keys), values.isRegularFile == true else { return nil }
            return (directory.appending(path: listed.lastPathComponent), values.contentModificationDate ?? .distantPast)
        }
        return files.sorted {
            $0.modified != $1.modified ? $0.modified > $1.modified : $0.url.lastPathComponent < $1.url.lastPathComponent
        }.map(\.url)
    }
}
