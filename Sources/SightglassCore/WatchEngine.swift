import Foundation

public enum WatchStatus: Equatable, Sendable {
    /// The file hasn't existed since watching started.
    case waiting
    case ok
    /// The file existed, then disappeared.
    case missing
    case invalid(String)
}

/// What changed since the last delivered update.
public struct WatchUpdate: Equatable, Sendable {
    public var status: WatchStatus
    /// A new value, if one was read.
    public var snapshot: Snapshot?
    /// The file's latest modification time.
    public var modified: Date?

    public init(status: WatchStatus, snapshot: Snapshot?, modified: Date?) {
        self.status = status
        self.snapshot = snapshot
        self.modified = modified
    }
}

/// Runs a `FileMonitor` and `SnapshotReader` on a private queue and delivers
/// coalesced updates — at most one per `minUpdateInterval` — on `callbackQueue`.
public final class WatchEngine: @unchecked Sendable {
    private let queue: DispatchQueue
    private let callbackQueue: DispatchQueue
    private let minUpdateInterval: TimeInterval
    private let onUpdate: @Sendable (WatchUpdate) -> Void
    private let reader: SnapshotReader
    private var monitor: FileMonitor!

    // Confined to `queue`.
    private var status: WatchStatus = .waiting
    private var modified: Date?
    private var hasSeenFile = false
    private var isPending = false
    private var queued: WatchUpdate?
    private var lastSent: (status: WatchStatus, modified: Date?) = (.waiting, nil)
    private var lastDelivery = Date.distantPast
    private var deliveryScheduled = false

    public init(
        url: URL,
        pollInterval: TimeInterval = 2,
        grace: TimeInterval = 5,
        minUpdateInterval: TimeInterval = 0.25,
        callbackQueue: DispatchQueue = .main,
        onUpdate: @escaping @Sendable (WatchUpdate) -> Void
    ) {
        queue = DispatchQueue(label: "sightglass.watch.\(url.lastPathComponent)")
        self.callbackQueue = callbackQueue
        self.minUpdateInterval = minUpdateInterval
        self.onUpdate = onUpdate
        reader = SnapshotReader(url: url, grace: grace)
        monitor = FileMonitor(url: url, queue: queue, pollInterval: pollInterval) { [weak self] event in
            self?.handle(event)
        }
    }

    public func start() { monitor.start() }
    public func stop() { monitor.stop() }

    private func handle(_ event: FileMonitor.Event) {
        switch event {
        case .missing:
            isPending = false
            enqueue(status: hasSeenFile ? .missing : .waiting, snapshot: nil)
        case .changed(let stat):
            hasSeenFile = true
            modified = stat.modified
            apply(reader.read(now: Date()))
        case .tick:
            // A broken file doesn't change on its own; re-read so the grace
            // period can expire into `.invalid`.
            if isPending { apply(reader.read(now: Date())) }
        }
    }

    private func apply(_ outcome: ReadOutcome) {
        isPending = outcome == .pending
        switch outcome {
        case .snapshot(let snapshot):
            enqueue(status: .ok, snapshot: snapshot)
        case .unchanged:
            enqueue(status: status, snapshot: nil)
        case .pending:
            enqueue(status: status == .missing ? .waiting : status, snapshot: nil)
        case .invalid(let message):
            enqueue(status: .invalid(message), snapshot: nil)
        case .missing:
            enqueue(status: hasSeenFile ? .missing : .waiting, snapshot: nil)
        }
    }

    private func enqueue(status newStatus: WatchStatus, snapshot: Snapshot?) {
        status = newStatus
        let changed = snapshot != nil || newStatus != lastSent.status || modified != lastSent.modified
        guard changed || queued != nil else { return }
        var update = queued ?? WatchUpdate(status: newStatus, snapshot: nil, modified: modified)
        update.status = newStatus
        update.modified = modified
        if let snapshot { update.snapshot = Self.merge(update.snapshot, snapshot) }
        queued = update
        scheduleDelivery()
    }

    /// Combines two snapshots waiting in the same delivery window, keeping
    /// the older one's seed and restart flag unless the newer one starts over.
    public static func merge(_ old: Snapshot?, _ new: Snapshot) -> Snapshot {
        guard let old, !new.isRestart, new.seed.isEmpty else { return new }
        var merged = new
        merged.seed = old.seed
        merged.isRestart = old.isRestart
        return merged
    }

    private func scheduleDelivery() {
        guard !deliveryScheduled else { return }
        deliveryScheduled = true
        let wait = max(0, minUpdateInterval - Date().timeIntervalSince(lastDelivery))
        queue.asyncAfter(deadline: .now() + wait) { [weak self] in self?.deliver() }
    }

    private func deliver() {
        deliveryScheduled = false
        guard let update = queued else { return }
        queued = nil
        lastDelivery = Date()
        lastSent = (update.status, update.modified)
        let onUpdate = onUpdate
        callbackQueue.async { onUpdate(update) }
    }
}
