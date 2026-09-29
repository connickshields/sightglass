import Foundation
import Testing
@testable import SightglassCore

@Suite(.serialized)
struct WatchEngineTests {
    static func start(_ url: URL, minUpdateInterval: TimeInterval = 0, updates: Recorder<WatchUpdate>) -> WatchEngine {
        let engine = WatchEngine(
            url: url, pollInterval: 0.1, grace: 0.3, minUpdateInterval: minUpdateInterval,
            callbackQueue: DispatchQueue(label: "test.callbacks")
        ) { updates.append($0) }
        engine.start()
        return engine
    }

    @Test func deliversSnapshotForExistingFile() async throws {
        let url = try makeTempDirectory().appending(path: "s.json")
        try url.overwrite(#"{"n": 1}"#)
        let updates = Recorder<WatchUpdate>()
        let engine = Self.start(url, updates: updates)
        defer { engine.stop() }
        #expect(await waitUntil { updates.all.last?.snapshot?.value == .object(["n": .number(1)]) })
        #expect(updates.all.last?.status == .ok)
        #expect(updates.all.last?.modified != nil)
    }

    @Test func waitsForFileToAppear() async throws {
        let url = try makeTempDirectory().appending(path: "s.json")
        let updates = Recorder<WatchUpdate>()
        let engine = Self.start(url, updates: updates)
        defer { engine.stop() }
        try await Task.sleep(for: .milliseconds(300))
        #expect(updates.all.isEmpty)  // still .waiting; nothing new to report
        try url.overwrite(#"{"n": 1}"#)
        #expect(await waitUntil { updates.all.last?.status == .ok })
    }

    @Test func reportsMissingAfterDeletion() async throws {
        let url = try makeTempDirectory().appending(path: "s.json")
        try url.overwrite(#"{"n": 1}"#)
        let updates = Recorder<WatchUpdate>()
        let engine = Self.start(url, updates: updates)
        defer { engine.stop() }
        #expect(await waitUntil { updates.all.last?.status == .ok })
        try FileManager.default.removeItem(at: url)
        #expect(await waitUntil { updates.all.last?.status == .missing })
    }

    @Test func reportsInvalidAfterGrace() async throws {
        let url = try makeTempDirectory().appending(path: "s.json")
        try url.overwrite("{")
        let updates = Recorder<WatchUpdate>()
        let engine = Self.start(url, updates: updates)
        defer { engine.stop() }
        #expect(await waitUntil {
            if case .invalid(let message) = updates.all.last?.status { return message.hasPrefix("Invalid JSON") }
            return false
        })
    }

    @Test func coalescesRapidUpdates() async throws {
        let url = try makeTempDirectory().appending(path: "s.json")
        try url.overwrite(#"{"n": 1}"#)
        let updates = Recorder<WatchUpdate>()
        let engine = Self.start(url, minUpdateInterval: 1.0, updates: updates)
        defer { engine.stop() }
        #expect(await waitUntil { updates.all.count == 1 })
        for n in 2...4 {
            try url.overwrite("{\"n\": \(n)}")
            try await Task.sleep(for: .milliseconds(50))
        }
        try await Task.sleep(for: .milliseconds(200))
        #expect(updates.all.count == 1)
        #expect(await waitUntil { updates.all.count == 2 })
        #expect(updates.all.last?.snapshot?.value == .object(["n": .number(4)]))
    }

    @Test func mergeKeepsSeedAndRestartUntilDelivered() {
        let seeded = Snapshot(value: .number(2), format: .ndjson, seed: [.number(1)], isRestart: true)
        let next = Snapshot(value: .number(3), format: .ndjson)
        #expect(WatchEngine.merge(seeded, next) == Snapshot(value: .number(3), format: .ndjson, seed: [.number(1)], isRestart: true))
        let restart = Snapshot(value: .number(9), format: .ndjson, seed: [.number(8)], isRestart: true)
        #expect(WatchEngine.merge(seeded, restart) == restart)
        #expect(WatchEngine.merge(nil, next) == next)
    }

    @Test func restartsHistoryWhenDocumentIsRecreated() async throws {
        let url = try makeTempDirectory().appending(path: "s.json")
        try url.overwrite(#"{"n": 1}"#)
        let updates = Recorder<WatchUpdate>()
        let engine = Self.start(url, updates: updates)
        defer { engine.stop() }
        #expect(await waitUntil { updates.all.last?.status == .ok })
        try FileManager.default.removeItem(at: url)
        #expect(await waitUntil { updates.all.last?.status == .missing })
        try url.overwrite(#"{"n": 2}"#)
        #expect(await waitUntil { updates.all.last?.snapshot?.value == .object(["n": .number(2)]) })
        #expect(updates.all.last?.snapshot?.isRestart == true)
    }

    @Test func restartsHistoryWhenLogIsRecreated() async throws {
        let url = try makeTempDirectory().appending(path: "events.ndjson")
        try url.overwrite("{\"n\": 1}\n{\"n\": 2}\n")
        let updates = Recorder<WatchUpdate>()
        let engine = Self.start(url, updates: updates)
        defer { engine.stop() }
        #expect(await waitUntil { updates.all.last?.status == .ok })
        try FileManager.default.removeItem(at: url)
        #expect(await waitUntil { updates.all.last?.status == .missing })
        try url.overwrite("{\"n\": 7}\n{\"n\": 8}\n")
        #expect(await waitUntil {
            guard let snapshot = updates.all.last?.snapshot, snapshot.value == .object(["n": .number(8)]) else { return false }
            return snapshot.isRestart && snapshot.seed == [.object(["n": .number(7)])]
        })
    }

    @Test func reportsUnreadableFileAsInvalid() async throws {
        let directory = try makeTempDirectory()
        let sub = directory.appending(path: "sub")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        let url = sub.appending(path: "s.json")
        try url.overwrite(#"{"n": 1}"#)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: sub.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: sub.path) }
        let updates = Recorder<WatchUpdate>()
        let engine = Self.start(url, updates: updates)
        defer { engine.stop() }
        #expect(await waitUntil {
            if case .invalid(let message) = updates.all.last?.status { return message.hasPrefix("Can't read file") }
            return false
        })
    }
}
