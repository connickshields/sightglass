import Foundation
import Testing
@testable import SightglassCore

struct FieldPathTests {
    @Test func parsesDottedAndIndexedPaths() throws {
        let path = try FieldPath(parsing: "stats.files[0].bytes")
        #expect(path.components == [.key("stats"), .key("files"), .index(0), .key("bytes")])
        #expect(path.description == "stats.files[0].bytes")
    }

    @Test func parsesQuotedKeys() throws {
        #expect(try FieldPath(parsing: #"["a.b"].c"#).components == [.key("a.b"), .key("c")])
        #expect(try FieldPath(parsing: #"["say \"hi\""]"#).components == [.key(#"say "hi""#)])
        #expect(try FieldPath(parsing: #"x["back\\slash"]"#).components == [.key("x"), .key(#"back\slash"#)])
    }

    @Test(arguments: ["a.b", "has space", "brack[et", #"quote""#, #"back\slash"#, "ünïcode", "", "0", "dash-and_underscore", "\u{301}x", "\"\u{301}"])
    func roundTripsAwkwardKeys(key: String) throws {
        let path = FieldPath([.key("outer"), .key(key), .index(3)])
        #expect(try FieldPath(parsing: path.description) == path)
    }

    @Test func formatsLeadingIndexAndQuotedFirstKey() {
        #expect(FieldPath([.index(0), .key("name")]).description == "[0].name")
        #expect(FieldPath([.key("a b"), .key("c")]).description == #"["a b"].c"#)
        #expect(FieldPath.root.description == "")
    }

    @Test(arguments: [".a", "a..b", "a[", "a[x]", "a b", #"a["x""#, "a]", "a.[0]"])
    func rejectsMalformedPaths(string: String) {
        #expect(throws: FieldPath.ParseError.self) { try FieldPath(parsing: string) }
    }

    @Test func resolvesAgainstValues() throws {
        let root = try JSONValue.parse(Data(#"{"stats": {"files": [{"bytes": 5}]}, "list": [1, 2]}"#.utf8))
        #expect(root[fp("stats.files[0].bytes")] == .number(5))
        #expect(root[fp("stats.missing")] == nil)
        #expect(root[fp("list[5]")] == nil)
        #expect(root[fp("list.key")] == nil)
        #expect(root[FieldPath.root] == root)
    }

    @Test func codesAsString() throws {
        let data = try JSONEncoder().encode([fp("a.b"), fp("c[1]")])
        #expect(String(decoding: data, as: UTF8.self) == #"["a.b","c[1]"]"#)
        #expect(try JSONDecoder().decode([FieldPath].self, from: data) == [fp("a.b"), fp("c[1]")])
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([FieldPath].self, from: Data(#"["a..b"]"#.utf8))
        }
    }

    @Test func lastKeyAndParent() {
        #expect(fp("a.b[2]").lastKey == "b")
        #expect(fp("a.b[2]").parent == fp("a.b"))
        #expect(fp("a").parent == .root)
        #expect(FieldPath.root.parent == nil)
        #expect(fp("a").appending(.index(1)) == fp("a[1]"))
    }
}
