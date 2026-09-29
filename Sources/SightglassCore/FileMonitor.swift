import Foundation

/// Identity and version of a file, used to detect real changes cheaply.
public struct FileStat: Equatable, Sendable {
    public var inode: UInt64
    public var size: Int64
    public var modified: Date

    public init(inode: UInt64, size: Int64, modified: Date) {
        self.inode = inode
        self.size = size
        self.modified = modified
    }

    /// `stat()`s `path`; nil if it doesn't exist or can't be read.
    public static func of(path: String) -> FileStat? {
        var info = stat()
        guard stat(path, &info) == 0 else { return nil }
        let mtime = info.st_mtimespec
        return FileStat(
            inode: UInt64(info.st_ino),
            size: Int64(info.st_size),
            modified: Date(timeIntervalSince1970: TimeInterval(mtime.tv_sec) + TimeInterval(mtime.tv_nsec) / 1e9)
        )
    }
}

/// Watches one path with a dispatch source for quick updates plus a safety
/// poll that catches missed events, network volumes, and files that don't
/// exist yet (spec §4.1). Survives atomic replacement and delete/recreate.
///
/// All state is confined to `queue`; events are delivered there.
public final class FileMonitor: @unchecked Sendable {
    public enum Event: Equatable, Sendable {
        case changed(FileStat)
        case missing
        /// Sent after every poll.
        case tick
    }

    private let path: String
    private let queue: DispatchQueue
    private let pollInterval: TimeInterval
    private let handler: @Sendable (Event) -> Void

    private var lastStat: FileStat?
    private var reportedMissing = false
    private var source: DispatchSourceFileSystemObject?
    private var timer: DispatchSourceTimer?

    public init(url: URL, queue: DispatchQueue, pollInterval: TimeInterval = 2, handler: @escaping @Sendable (Event) -> Void) {
        self.path = url.path
        self.queue = queue
        self.pollInterval = pollInterval
        self.handler = handler
    }

    public func start() {
        queue.async { [self] in
            guard timer == nil else { return }
            check()
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now() + pollInterval, repeating: pollInterval, leeway: .milliseconds(100))
            timer.setEventHandler { [weak self] in
                guard let self else { return }
                check()
                handler(.tick)
            }
            timer.resume()
            self.timer = timer
        }
    }

    public func stop() {
        queue.async { [self] in
            timer?.cancel()
            timer = nil
            closeSource()
        }
    }

    deinit {
        timer?.cancel()
        source?.cancel()
    }

    /// Compares the file's stat with the last one and reports differences.
    private func check() {
        guard let current = FileStat.of(path: path) else {
            closeSource()
            lastStat = nil
            if !reportedMissing {
                reportedMissing = true
                handler(.missing)
            }
            return
        }
        reportedMissing = false
        if source == nil { openSource() }
        if current != lastStat {
            lastStat = current
            handler(.changed(current))
        }
    }

    private func openSource() {
        let descriptor = open(path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .delete, .rename, .attrib],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            guard let self, let source = self.source else { return }
            // Deleted or replaced: stop watching the old inode; check() reopens.
            if !source.data.isDisjoint(with: [.delete, .rename]) { closeSource() }
            check()
        }
        source.setCancelHandler { close(descriptor) }
        self.source = source
        source.resume()
    }

    private func closeSource() {
        source?.cancel()
        source = nil
    }
}
