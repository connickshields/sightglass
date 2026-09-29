import Foundation
import Testing
@testable import SightglassCore

struct SnapshotReaderTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    func setUp(_ name: String = "status.json", seedWindow: Int = 256 * 1024) throws -> (URL, SnapshotReader) {
        let url = try makeTempDirectory().appending(path: name)
        return (url, SnapshotReader(url: url, seedWindow: seedWindow, grace: 5))
    }

    func obj(_ n: Int) -> JSONValue { .object(["n": .number(Double(n))]) }
    func line(_ n: Int) -> String { "{\"n\": \(n)}\n" }

    @Test func readsDocuments() throws {
        let (url, reader) = try setUp()
        try url.overwrite(#"{"n": 1}"#)
        #expect(reader.read(now: t0) == .snapshot(Snapshot(value: obj(1), format: .document)))
        try url.overwrite(#"{"n": 2}"#)
        #expect(reader.read(now: t0) == .snapshot(Snapshot(value: obj(2), format: .document)))
    }

    @Test func detectsNDJSONAndSeedsHistory() throws {
        let (url, reader) = try setUp("events.ndjson")
        try url.overwrite(line(1) + line(2) + line(3))
        #expect(reader.read(now: t0) == .snapshot(Snapshot(value: obj(3), format: .ndjson, seed: [obj(1), obj(2)])))
    }

    @Test func tailsAppendedLines() throws {
        let (url, reader) = try setUp("events.ndjson")
        try url.overwrite(line(1) + line(2))
        _ = reader.read(now: t0)
        try url.append(line(3))
        #expect(reader.read(now: t0) == .snapshot(Snapshot(value: obj(3), format: .ndjson)))
        try url.append(#"{"n": "#)
        #expect(reader.read(now: t0) == .unchanged)
        try url.append("4}\n")
        #expect(reader.read(now: t0) == .snapshot(Snapshot(value: obj(4), format: .ndjson)))
    }

    @Test func switchesFromDocumentToNDJSONWhenASecondLineArrives() throws {
        let (url, reader) = try setUp("events.ndjson")
        try url.overwrite(line(1))
        #expect(reader.read(now: t0) == .snapshot(Snapshot(value: obj(1), format: .document)))
        try url.append(line(2))
        #expect(reader.read(now: t0) == .snapshot(Snapshot(value: obj(2), format: .ndjson, seed: [obj(1)])))
    }

    @Test func halfWrittenPrettyDocumentIsNotNDJSON() throws {
        let (url, reader) = try setUp()
        try url.overwrite("{\n  \"files\": [\n    {\"name\": \"b\"}\n")
        #expect(reader.read(now: t0) == .pending)
        guard case .invalid(let message) = reader.read(now: t0.addingTimeInterval(6)) else {
            Issue.record("expected invalid")
            return
        }
        #expect(message.hasPrefix("Invalid JSON: "))
    }

    @Test func inPlaceRewriteIsPendingNotInvalid() throws {
        let (url, reader) = try setUp()
        try url.overwrite(#"{"n": 1}"#)
        _ = reader.read(now: t0)
        try url.overwrite("")
        #expect(reader.read(now: t0.addingTimeInterval(1)) == .pending)
        try url.overwrite(#"{"n": 2}"#)
        #expect(reader.read(now: t0.addingTimeInterval(2)) == .snapshot(Snapshot(value: obj(2), format: .document)))
    }

    @Test func emptyFileBecomesInvalidAfterGrace() throws {
        let (url, reader) = try setUp()
        try url.overwrite("")
        #expect(reader.read(now: t0) == .pending)
        #expect(reader.read(now: t0.addingTimeInterval(4)) == .pending)
        #expect(reader.read(now: t0.addingTimeInterval(5)) == .invalid("File is empty"))
    }

    @Test func missingFile() throws {
        let (url, reader) = try setUp()
        #expect(reader.read(now: t0) == .missing)
        try url.overwrite(#"{"n": 1}"#)
        #expect(reader.read(now: t0) == .snapshot(Snapshot(value: obj(1), format: .document)))
    }

    @Test func truncatedLogIsRestart() throws {
        let (url, reader) = try setUp("events.ndjson")
        try url.overwrite(line(1) + line(2) + line(3))
        _ = reader.read(now: t0)
        try url.overwrite(line(1) + line(2))
        #expect(reader.read(now: t0) == .snapshot(Snapshot(value: obj(2), format: .ndjson, seed: [obj(1)], isRestart: true)))
    }

    @Test func truncatedToEmptyThenRefilledIsStillRestart() throws {
        let (url, reader) = try setUp("events.ndjson")
        try url.overwrite(line(1) + line(2) + line(3))
        _ = reader.read(now: t0)
        try url.overwrite("")
        #expect(reader.read(now: t0) == .pending)
        try url.append(line(1) + line(2))
        #expect(reader.read(now: t0) == .snapshot(Snapshot(value: obj(2), format: .ndjson, seed: [obj(1)], isRestart: true)))
    }

    @Test func replacedLogIsRestart() throws {
        let (url, reader) = try setUp("events.ndjson")
        try url.overwrite(line(1) + line(2))
        _ = reader.read(now: t0)
        try url.replaceAtomically(line(7) + line(8))
        #expect(reader.read(now: t0) == .snapshot(Snapshot(value: obj(8), format: .ndjson, seed: [obj(7)], isRestart: true)))
    }

    @Test func seedsFromTheTailOfLargeLogs() throws {
        let (url, reader) = try setUp("events.ndjson", seedWindow: 1024)
        try url.overwrite((1...1000).map(line).joined())
        guard case .snapshot(let snapshot) = reader.read(now: t0) else {
            Issue.record("expected snapshot")
            return
        }
        #expect(snapshot.value == obj(1000))
        #expect(snapshot.seed.last == obj(999))
        #expect(snapshot.seed.count > 50 && snapshot.seed.count < 200)
        try url.append(line(1001))
        #expect(reader.read(now: t0) == .snapshot(Snapshot(value: obj(1001), format: .ndjson)))
    }

    @Test func readsLargeDocuments() throws {
        let (url, reader) = try setUp(seedWindow: 64)
        let pretty = "{\n" + (1...20).map { "  \"k\($0)\": \($0)" }.joined(separator: ",\n") + "\n}\n"
        try url.overwrite(pretty)
        guard case .snapshot(let snapshot) = reader.read(now: t0) else {
            Issue.record("expected snapshot")
            return
        }
        #expect(snapshot.format == .document)
        #expect(snapshot.value[fp("k20")] == .number(20))
    }

    @Test func skipsBadLinesOnceEstablished() throws {
        let (url, reader) = try setUp("events.ndjson")
        try url.overwrite(line(1) + line(2))
        _ = reader.read(now: t0)
        try url.append("garbage\n" + line(9))
        #expect(reader.read(now: t0) == .snapshot(Snapshot(value: obj(9), format: .ndjson)))
    }

    @Test func handlesCRLF() throws {
        let (url, reader) = try setUp("events.ndjson")
        try url.overwrite("{\"n\": 1}\r\n{\"n\": 2}\r\n")
        #expect(reader.read(now: t0) == .snapshot(Snapshot(value: obj(2), format: .ndjson, seed: [obj(1)])))
    }

    @Test func refilledLogLongerThanBeforeIsRestart() throws {
        let (url, reader) = try setUp("events.ndjson")
        try url.overwrite(line(1) + line(2))
        _ = reader.read(now: t0)
        try url.overwrite(line(7) + line(8) + line(9))
        #expect(reader.read(now: t0) == .snapshot(Snapshot(value: obj(9), format: .ndjson, seed: [obj(7), obj(8)], isRestart: true)))
    }

    @Test func recreatedDocumentIsRestart() throws {
        let (url, reader) = try setUp()
        try url.overwrite(#"{"n": 1}"#)
        _ = reader.read(now: t0)
        try FileManager.default.removeItem(at: url)
        #expect(reader.read(now: t0) == .missing)
        try url.overwrite(#"{"n": 2}"#)
        #expect(reader.read(now: t0) == .snapshot(Snapshot(value: obj(2), format: .document, isRestart: true)))
    }

    @Test func refilledLogAfterIdleReadIsRestart() throws {
        let (url, reader) = try setUp("events.ndjson")
        try url.overwrite(line(1) + line(2))
        _ = reader.read(now: t0)
        #expect(reader.read(now: t0) == .unchanged)
        try url.append(line(3))
        #expect(reader.read(now: t0) == .snapshot(Snapshot(value: obj(3), format: .ndjson)))
        #expect(reader.read(now: t0) == .unchanged)
        try url.overwrite(line(7) + line(8) + line(9) + line(10))
        #expect(reader.read(now: t0) == .snapshot(Snapshot(value: obj(10), format: .ndjson, seed: [obj(7), obj(8), obj(9)], isRestart: true)))
    }
}
