import Foundation

/// What a watch shows: latest value, status, and per-path histories.
public struct WatchState: Equatable, Sendable {
    public private(set) var value: JSONValue?
    public private(set) var status: WatchStatus = .waiting
    public private(set) var modified: Date?
    private var histories: [FieldPath: History] = [:]
    private let historyCapacity: Int

    public init(historyCapacity: Int = 300) {
        self.historyCapacity = historyCapacity
    }

    public func history(for path: FieldPath) -> History {
        histories[path] ?? History(capacity: historyCapacity)
    }

    /// Applies an engine update, recording numeric values at `trackedPaths`.
    /// Status-only updates keep the last good value.
    public mutating func apply(_ update: WatchUpdate, trackedPaths: Set<FieldPath>, now: Date) {
        status = update.status
        if let modified = update.modified { self.modified = modified }
        guard let snapshot = update.snapshot else { return }
        if snapshot.isRestart { histories.removeAll() }
        for path in trackedPaths {
            var pathHistory = history(for: path)
            for seeded in snapshot.seed {
                if let number = seeded[path]?.doubleValue { pathHistory.record(number, at: nil) }
            }
            if let number = snapshot.value[path]?.doubleValue { pathHistory.record(number, at: now) }
            histories[path] = pathHistory
        }
        value = snapshot.value
    }

    public func isStale(now: Date, staleAfter: TimeInterval?) -> Bool {
        status == .ok && Staleness.isStale(lastModified: modified, now: now, staleAfter: staleAfter)
    }

    /// Show the warning triangle and dim values: missing, invalid, or stale.
    public func needsAttention(now: Date, staleAfter: TimeInterval?) -> Bool {
        switch status {
        case .missing, .invalid: true
        case .waiting: false
        case .ok: isStale(now: now, staleAfter: staleAfter)
        }
    }

    /// One line for the menu header.
    public func statusLine(now: Date, staleAfter: TimeInterval?) -> String {
        switch status {
        case .waiting:
            return "Waiting for file"
        case .missing:
            return "File not found"
        case .invalid(let message):
            return message
        case .ok:
            guard let modified else { return "Updated just now" }
            let age = ValueFormatter.shortDuration(now.timeIntervalSince(modified))
            if isStale(now: now, staleAfter: staleAfter) { return "Stale — no updates for \(age)" }
            return "Updated \(age) ago"
        }
    }
}
