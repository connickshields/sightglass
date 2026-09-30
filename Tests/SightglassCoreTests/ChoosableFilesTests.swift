import Foundation
import Testing
@testable import SightglassCore

struct ChoosableFilesTests {
    func makeFile(_ name: String, in directory: URL, modified: Date) throws -> URL {
        let url = directory.appending(path: name)
        try url.overwrite("{}")
        try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
        return url
    }

    @Test func listsNewestFirst() throws {
        let directory = try makeTempDirectory()
        let now = Date()
        _ = try makeFile("old.json", in: directory, modified: now.addingTimeInterval(-60))
        _ = try makeFile("status.json", in: directory, modified: now)
        _ = try makeFile("events.ndjson", in: directory, modified: now.addingTimeInterval(-10))
        let names = try ChoosableFiles.list(in: directory).map(\.lastPathComponent)
        #expect(names == ["status.json", "events.ndjson", "old.json"])
    }

    @Test func breaksTiesByName() throws {
        let directory = try makeTempDirectory()
        let now = Date()
        _ = try makeFile("b.json", in: directory, modified: now)
        _ = try makeFile("a.json", in: directory, modified: now)
        let names = try ChoosableFiles.list(in: directory).map(\.lastPathComponent)
        #expect(names == ["a.json", "b.json"])
    }

    @Test func skipsHiddenFilesAndFolders() throws {
        let directory = try makeTempDirectory()
        _ = try makeFile("status.json", in: directory, modified: Date())
        _ = try makeFile(".hidden.json", in: directory, modified: Date())
        try FileManager.default.createDirectory(at: directory.appending(path: "logs"), withIntermediateDirectories: false)
        let names = try ChoosableFiles.list(in: directory).map(\.lastPathComponent)
        #expect(names == ["status.json"])
    }

    @Test func returnsPathsInTheFolder() throws {
        let directory = try makeTempDirectory()
        let file = try makeFile("status.json", in: directory, modified: Date())
        #expect(try ChoosableFiles.list(in: directory).map(\.path) == [file.path])
    }

    @Test func throwsForAMissingFolder() throws {
        let directory = try makeTempDirectory().appending(path: "missing")
        #expect(throws: (any Error).self) { try ChoosableFiles.list(in: directory) }
    }
}
