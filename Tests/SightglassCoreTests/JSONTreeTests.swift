import Foundation
import Testing
@testable import SightglassCore

struct JSONTreeTests {
    let root = try! JSONValue.parse(Data(#"{"b": {"y": 2, "x": "s"}, "a": [1, true]}"#.utf8))
    let big = JSONValue.object(["files": .array((0..<10_000).map { .object(["bytes": .number(Double($0))]) })])

    @Test func sortsKeysAndNests() {
        let nodes = JSONTree.nodes(for: root)
        #expect(nodes.map(\.title) == ["a", "b"])
        #expect(nodes[0].children?.map(\.title) == ["[0]", "[1]"])
        #expect(nodes[1].children?.map(\.id) == ["b.x", "b.y"])
        #expect(nodes[1].summary == "{2 keys}")
        #expect(nodes[1].leafValue == nil)
        #expect(nodes[1].children?[1].leafValue == .number(2))
        #expect(nodes[1].children?[1].children == nil)
    }

    @Test func scalarRoot() {
        let nodes = JSONTree.nodes(for: .number(7))
        #expect(nodes.count == 1)
        #expect(nodes[0].path == .root)
        #expect(nodes[0].title == "(value)")
        #expect(nodes[0].leafValue == .number(7))
    }

    @Test func capsLargeArrays() {
        let files = JSONTree.nodes(for: big, arrayLimit: 100)[0].children ?? []
        #expect(files.count == 101)
        #expect(files.last?.title == "… 9900 more")
        #expect(files.last?.id == "files#more")
        #expect(files.last?.leafValue == nil)
        #expect(files.last?.children == nil)
    }

    @Test func numericLeafPathsRespectCap() {
        #expect(JSONTree.numericLeafPaths(in: big, arrayLimit: 100).count == 100)
        let mixed = JSONValue.object(["n": .number(1), "s": .string("2"), "t": .string("x"), "b": .bool(true)])
        #expect(JSONTree.numericLeafPaths(in: mixed) == [fp("n"), fp("s")])
        #expect(JSONTree.numericLeafPaths(in: nil) == [])
    }
}
