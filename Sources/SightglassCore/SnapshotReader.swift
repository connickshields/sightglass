import Foundation

public enum FileFormat: Equatable, Sendable {
    case document
    case ndjson
}

public struct Snapshot: Equatable, Sendable {
    public var value: JSONValue
    public var format: FileFormat
    /// Earlier NDJSON lines (oldest first) from a full read, for seeding history.
    public var seed: [JSONValue]
    /// True when the file was truncated, replaced, or deleted and recreated, so
    /// history from before no longer applies.
    public var isRestart: Bool

    public init(value: JSONValue, format: FileFormat, seed: [JSONValue] = [], isRestart: Bool = false) {
        self.value = value
        self.format = format
        self.seed = seed
        self.isRestart = isRestart
    }
}

public enum ReadOutcome: Equatable, Sendable {
    case snapshot(Snapshot)
    /// Nothing new, e.g. an NDJSON line is still being written.
    case unchanged
    /// The file doesn't parse yet; keep showing the last value.
    case pending
    /// The file has failed to parse for longer than the grace period.
    case invalid(String)
    case missing
}

/// Reads a watched file, detecting whole-document JSON vs NDJSON (spec §4.2).
/// Not thread-safe: use it from one queue.
public final class SnapshotReader {
    public let url: URL
    private let seedWindow: Int
    private let grace: TimeInterval

    private var format: FileFormat?
    private var inode: UInt64?
    private var offset: UInt64 = 0
    private var signature = Data()
    private var partialLine = Data()
    private var failingSince: Date?
    private var restartPending = false

    public init(url: URL, seedWindow: Int = 256 * 1024, grace: TimeInterval = 5) {
        self.url = url
        self.seedWindow = seedWindow
        self.grace = grace
    }

    public func read(now: Date = Date()) -> ReadOutcome {
        guard FileManager.default.fileExists(atPath: url.path) else {
            if format != nil { restartPending = true }
            clearPosition()
            failingSince = nil
            return .missing
        }
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: url)
        } catch {
            return fail("Can't read file: \(error.localizedDescription)", now: now)
        }
        defer { try? handle.close() }

        var info = stat()
        guard fstat(handle.fileDescriptor, &info) == 0 else { return fail("Can't read file", now: now) }
        let fileInode = UInt64(info.st_ino)
        let size = UInt64(max(0, info.st_size))

        do {
            if format == .ndjson, inode == fileInode, size >= offset {
                // Check if signature matches to detect truncate+refill on same inode
                if !signature.isEmpty {
                    let signatureStart = max(0, offset - UInt64(signature.count))
                    try handle.seek(toOffset: signatureStart)
                    let checkData = try handle.read(upToCount: signature.count) ?? Data()
                    if checkData != signature {
                        restartPending = true
                        try handle.seek(toOffset: 0)
                        return try fullRead(handle, inode: fileInode, size: size, now: now)
                    }
                }
                return try tail(handle, size: size)
            }
            if format == .ndjson { restartPending = true }
            try handle.seek(toOffset: 0)
            return try fullRead(handle, inode: fileInode, size: size, now: now)
        } catch {
            return fail("Can't read file: \(error.localizedDescription)", now: now)
        }
    }

    // MARK: - Reading

    /// Reads only bytes appended since the last read.
    private func tail(_ handle: FileHandle, size: UInt64) throws -> ReadOutcome {
        try handle.seek(toOffset: offset)
        let data = try handle.read(upToCount: Int(size - offset)) ?? Data()
        offset += UInt64(data.count)
        setSignature(data: partialLine + data)
        let (lines, rest) = Self.splitLines(partialLine + data)
        partialLine = rest
        // Once a file is known to be NDJSON, bad lines are skipped.
        guard let last = lines.compactMap(Self.parseLine).last else { return .unchanged }
        return succeed(Snapshot(value: last, format: .ndjson))
    }

    private func fullRead(_ handle: FileHandle, inode fileInode: UInt64, size: UInt64, now: Date) throws -> ReadOutcome {
        clearPosition()

        // Big files are usually logs: try NDJSON on the tail first.
        if size > UInt64(seedWindow) {
            let start = size - UInt64(seedWindow)
            try handle.seek(toOffset: start)
            let window = try handle.read(upToCount: seedWindow) ?? Data()
            // Drop the first line; the window probably starts mid-line.
            if let newline = window.firstIndex(of: 0x0A),
               let outcome = ndjson(Data(window[(newline + 1)...]), inode: fileInode, end: start + UInt64(window.count)) {
                return outcome
            }
            try handle.seek(toOffset: 0)
        }

        let data = try handle.readToEnd() ?? Data()
        do {
            let value = try JSONValue.parse(data)
            format = .document
            inode = fileInode
            return succeed(Snapshot(value: value, format: .document))
        } catch {
            if let outcome = ndjson(data, inode: fileInode, end: UInt64(data.count)) { return outcome }
            return fail(Self.message(for: error, data: data), now: now)
        }
    }

    /// Treats `data` as NDJSON if every complete line is a JSON object or array.
    private func ndjson(_ data: Data, inode fileInode: UInt64, end: UInt64) -> ReadOutcome? {
        let (lines, rest) = Self.splitLines(data)
        guard !lines.isEmpty else { return nil }
        var values: [JSONValue] = []
        for line in lines {
            guard let value = Self.parseLine(line) else { return nil }
            values.append(value)
        }
        format = .ndjson
        inode = fileInode
        offset = end
        setSignature(data: data)
        partialLine = rest
        return succeed(Snapshot(value: values[values.count - 1], format: .ndjson, seed: Array(values.dropLast())))
    }

    // MARK: - State

    private func succeed(_ snapshot: Snapshot) -> ReadOutcome {
        var snapshot = snapshot
        snapshot.isRestart = restartPending
        restartPending = false
        failingSince = nil
        return .snapshot(snapshot)
    }

    private func fail(_ message: String, now: Date) -> ReadOutcome {
        let since = failingSince ?? now
        failingSince = since
        return now.timeIntervalSince(since) >= grace ? .invalid(message) : .pending
    }

    private func clearPosition() {
        format = nil
        inode = nil
        offset = 0
        signature = Data()
        partialLine = Data()
    }

    /// Sets signature to the last up to 64 bytes of the data.
    private func setSignature(data: Data) {
        let maxSigSize = 64
        if data.count >= maxSigSize {
            signature = Data(data[(data.count - maxSigSize)...])
        } else {
            signature = data
        }
    }

    // MARK: - Parsing

    /// Complete (newline-terminated), non-blank lines plus the unterminated rest.
    static func splitLines(_ data: Data) -> (lines: [Data], rest: Data) {
        guard let lastNewline = data.lastIndex(of: 0x0A) else { return ([], data) }
        let lines = data[data.startIndex..<lastNewline]
            .split(separator: 0x0A, omittingEmptySubsequences: true)
            .filter { line in !line.allSatisfy { $0 == 0x20 || $0 == 0x09 || $0 == 0x0D } }
            .map { Data($0) }
        return (lines, Data(data[(lastNewline + 1)...]))
    }

    /// A line's value if it's a JSON object or array.
    static func parseLine(_ line: Data) -> JSONValue? {
        guard let value = try? JSONValue.parse(line), value.isContainer else { return nil }
        return value
    }

    static func message(for error: Error, data: Data) -> String {
        if data.allSatisfy({ $0 == 0x20 || $0 == 0x09 || $0 == 0x0A || $0 == 0x0D }) {
            return "File is empty"
        }
        let detail = (error as NSError).userInfo[NSDebugDescriptionErrorKey] as? String ?? error.localizedDescription
        return "Invalid JSON: " + detail.replacingOccurrences(of: ". around", with: " around")
    }
}
