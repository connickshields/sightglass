import Foundation
import Testing
@testable import SightglassCore

struct ConfigStoreTests {
    func makeStore() throws -> ConfigStore {
        ConfigStore(url: try makeTempDirectory().appending(path: "nested/config.json"))
    }

    func prepareDirectory(_ store: ConfigStore) throws {
        try FileManager.default.createDirectory(at: store.url.deletingLastPathComponent(), withIntermediateDirectories: true)
    }

    @Test func missingFileLoadsEmpty() throws {
        let result = try makeStore().load()
        #expect(result.watches.isEmpty)
        #expect(result.backupURL == nil)
    }

    @Test func roundTrips() throws {
        let store = try makeStore()
        let watch = WatchConfig(path: "/tmp/status.json", fields: [
            FieldConfig(path: fp("progress.downloaded"), label: "DL", display: .bar(source: .ratio(total: fp("progress.total")), showsPercent: true)),
            FieldConfig(path: fp("status"), display: .badge(rules: BadgeRule.defaults)),
            FieldConfig(path: fp("bytes"), display: .rate(total: nil, unit: nil), format: .bytes),
        ], staleAfter: nil)
        try store.save([watch])
        #expect(store.load().watches == [watch])
    }

    @Test func writesVersionedPrettyJSON() throws {
        let store = try makeStore()
        try store.save([WatchConfig(path: "/tmp/a.json")])
        let text = try String(contentsOf: store.url, encoding: .utf8)
        #expect(text.contains(#""version" : 1"#))
        #expect(text.contains(#""path" : "/tmp/a.json""#))
    }

    @Test func expandsTildeOnLoad() throws {
        let store = try makeStore()
        try prepareDirectory(store)
        try store.url.overwrite(#"{"version": 1, "watches": [{"id": "5D7A4C1E-0000-4000-8000-000000000001", "path": "~/x.json", "name": "x", "fields": [], "staleAfter": 300}]}"#)
        #expect(store.load().watches.first?.path == NSHomeDirectory() + "/x.json")
    }

    @Test func corruptFileIsBackedUp() throws {
        let store = try makeStore()
        try prepareDirectory(store)
        try store.url.overwrite("{ not json")
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let result = store.load(now: now)
        #expect(result.watches.isEmpty)
        let backup = try #require(result.backupURL)
        #expect(backup.lastPathComponent == "config.json.bak-\(ConfigStore.stamp(now))")
        #expect(try String(contentsOf: backup, encoding: .utf8) == "{ not json")
        #expect(!FileManager.default.fileExists(atPath: store.url.path))
    }

    @Test func watchConfigDefaults() {
        let config = WatchConfig(path: "/jobs/download-status.json")
        #expect(config.name == "download-status.json")
        #expect(config.staleAfter == 300)
        #expect(config.url.path == "/jobs/download-status.json")
        let withFields = WatchConfig(path: "/a", fields: [
            FieldConfig(path: fp("x")), FieldConfig(path: fp("x"), display: .sparkline(samples: 60)), FieldConfig(path: fp("y")),
        ])
        #expect(withFields.trackedPaths == [fp("x"), fp("y")])
    }
}
