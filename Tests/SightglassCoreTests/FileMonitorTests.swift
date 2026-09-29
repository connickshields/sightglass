import Foundation
import Testing
@testable import SightglassCore

@Suite(.serialized)
struct FileMonitorTests {
    static func start(_ url: URL, poll: TimeInterval, events: Recorder<FileMonitor.Event>) -> FileMonitor {
        let monitor = FileMonitor(url: url, queue: DispatchQueue(label: "test.monitor"), pollInterval: poll) { events.append($0) }
        monitor.start()
        return monitor
    }

    static func changes(_ events: Recorder<FileMonitor.Event>) -> [FileStat] {
        events.all.compactMap { event in
            if case .changed(let stat) = event { stat } else { nil }
        }
    }

    @Test func reportsMissingThenAppearance() async throws {
        let url = try makeTempDirectory().appending(path: "status.json")
        let events = Recorder<FileMonitor.Event>()
        let monitor = Self.start(url, poll: 0.1, events: events)
        defer { monitor.stop() }
        #expect(await waitUntil { events.all.contains(.missing) })
        try url.overwrite("{}")
        #expect(await waitUntil { Self.changes(events).count == 1 })
    }

    @Test func detectsWritesThroughDispatchSource() async throws {
        let url = try makeTempDirectory().appending(path: "status.json")
        try url.overwrite("{}")
        let events = Recorder<FileMonitor.Event>()
        let monitor = Self.start(url, poll: 60, events: events)  // poll too slow to matter
        defer { monitor.stop() }
        #expect(await waitUntil { Self.changes(events).count == 1 })
        try url.append(" ")
        #expect(await waitUntil { Self.changes(events).count == 2 })
        #expect(Self.changes(events).last?.size == 3)
    }

    @Test func followsAtomicReplacement() async throws {
        let url = try makeTempDirectory().appending(path: "status.json")
        try url.overwrite("{}")
        let events = Recorder<FileMonitor.Event>()
        let monitor = Self.start(url, poll: 60, events: events)
        defer { monitor.stop() }
        #expect(await waitUntil { Self.changes(events).count == 1 })
        try url.replaceAtomically(#"{"a": 1}"#)
        #expect(await waitUntil { Self.changes(events).count == 2 })
        let stats = Self.changes(events)
        #expect(stats[0].inode != stats[1].inode)
        // The source must now be watching the new file.
        try url.append(" ")
        #expect(await waitUntil { Self.changes(events).count == 3 })
    }

    @Test func reportsDeletionAndRecreation() async throws {
        let url = try makeTempDirectory().appending(path: "status.json")
        try url.overwrite("{}")
        let events = Recorder<FileMonitor.Event>()
        let monitor = Self.start(url, poll: 0.1, events: events)
        defer { monitor.stop() }
        #expect(await waitUntil { Self.changes(events).count == 1 })
        try FileManager.default.removeItem(at: url)
        #expect(await waitUntil { events.all.contains(.missing) })
        try url.overwrite("{}")
        #expect(await waitUntil { Self.changes(events).count == 2 })
    }

    @Test func sendsTicksWithoutDuplicateChanges() async throws {
        let url = try makeTempDirectory().appending(path: "status.json")
        try url.overwrite("{}")
        let events = Recorder<FileMonitor.Event>()
        let monitor = Self.start(url, poll: 0.05, events: events)
        defer { monitor.stop() }
        #expect(await waitUntil { events.all.filter { $0 == .tick }.count >= 5 })
        #expect(Self.changes(events).count == 1)
    }

    @Test func startingTwiceStillStopsCleanly() async throws {
        let url = try makeTempDirectory().appending(path: "status.json")
        try url.overwrite("{}")
        let events = Recorder<FileMonitor.Event>()
        let monitor = FileMonitor(url: url, queue: DispatchQueue(label: "test.monitor.twice"), pollInterval: 0.05) { events.append($0) }
        monitor.start()
        monitor.start()
        defer { monitor.stop() }
        #expect(await waitUntil { events.all.filter { $0 == .tick }.count >= 3 })
        monitor.stop()
        try await Task.sleep(for: .milliseconds(200))
        let countBefore = events.all.filter { $0 == .tick }.count
        try await Task.sleep(for: .milliseconds(300))
        let countAfter = events.all.filter { $0 == .tick }.count
        #expect(countBefore == countAfter)
    }

    @Test func droppingTheMonitorStopsEvents() async throws {
        let url = try makeTempDirectory().appending(path: "status.json")
        try url.overwrite("{}")
        let events = Recorder<FileMonitor.Event>()
        var monitor: FileMonitor? = FileMonitor(url: url, queue: DispatchQueue(label: "test.monitor.drop"), pollInterval: 0.05) { events.append($0) }
        monitor?.start()
        #expect(await waitUntil { events.all.filter { $0 == .tick }.count >= 3 })
        monitor = nil
        try await Task.sleep(for: .milliseconds(200))
        let countBefore = events.all.filter { $0 == .tick }.count
        try await Task.sleep(for: .milliseconds(300))
        let countAfter = events.all.filter { $0 == .tick }.count
        #expect(countBefore == countAfter)
    }

    @Test func reportsUnreadableInsteadOfMissing() async throws {
        let sub = try makeTempDirectory().appending(path: "sub")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        let url = sub.appending(path: "status.json")
        try url.overwrite("{}")
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: sub.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: sub.path) }
        let events = Recorder<FileMonitor.Event>()
        let monitor = Self.start(url, poll: 0.05, events: events)
        defer { monitor.stop() }
        #expect(await waitUntil { events.all.contains(.unreadable) })
        try await Task.sleep(for: .milliseconds(200))
        #expect(!events.all.contains(.missing))
        #expect(events.all.filter { $0 == .unreadable }.count == 1)
    }
}
