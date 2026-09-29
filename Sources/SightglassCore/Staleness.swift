import Foundation

public enum Staleness {
    /// True when the file hasn't changed for longer than `staleAfter`.
    /// A nil `staleAfter` turns the check off.
    public static func isStale(lastModified: Date?, now: Date, staleAfter: TimeInterval?) -> Bool {
        guard let lastModified, let staleAfter else { return false }
        return now.timeIntervalSince(lastModified) > staleAfter
    }
}
