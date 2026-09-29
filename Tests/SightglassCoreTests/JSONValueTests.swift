import Foundation
import Testing
@testable import SightglassCore

struct JSONValueTests {
    @Test func parsesNestedValues() throws {
        let value = try JSONValue.parse(Data(#"{"a": 1, "b": true, "c": "x", "d": null, "e": [1.5]}"#.utf8))
        #expect(value == .object([
            "a": .number(1), "b": .bool(true), "c": .string("x"), "d": .null, "e": .array([.number(1.5)]),
        ]))
    }

    @Test func distinguishesBoolsFromNumbers() throws {
        let value = try JSONValue.parse(Data("[true, 1, 0, false]".utf8))
        #expect(value == .array([.bool(true), .number(1), .number(0), .bool(false)]))
    }

    @Test func parsesTopLevelScalars() throws {
        #expect(try JSONValue.parse(Data("42".utf8)) == .number(42))
        #expect(try JSONValue.parse(Data(#""hi""#.utf8)) == .string("hi"))
    }

    @Test func rejectsInvalidJSON() {
        #expect(throws: (any Error).self) { try JSONValue.parse(Data(#"{"a": 1,"#.utf8)) }
    }

    @Test func doubleValueAcceptsNumbersAndNumericStrings() {
        #expect(JSONValue.number(2.5).doubleValue == 2.5)
        #expect(JSONValue.string(" 42 ").doubleValue == 42)
        #expect(JSONValue.string("3.5").doubleValue == 3.5)
        #expect(JSONValue.string("abc").doubleValue == nil)
        #expect(JSONValue.string("nan").doubleValue == nil)
        #expect(JSONValue.bool(true).doubleValue == nil)
        #expect(JSONValue.null.doubleValue == nil)
    }

    @Test func displayStrings() {
        #expect(JSONValue.number(1000).displayString == "1000")
        #expect(JSONValue.number(2.5).displayString == "2.5")
        #expect(JSONValue.bool(false).displayString == "false")
        #expect(JSONValue.null.displayString == "null")
        #expect(JSONValue.string("done").displayString == "done")
        #expect(JSONValue.array([.null]).displayString == "[1 item]")
        #expect(JSONValue.array([.null, .null]).displayString == "[2 items]")
        #expect(JSONValue.object(["a": .null]).displayString == "{1 key}")
        #expect(JSONValue.object([:]).displayString == "{0 keys}")
    }

    @Test func containers() {
        #expect(JSONValue.object([:]).isContainer)
        #expect(JSONValue.array([]).isContainer)
        #expect(!JSONValue.string("x").isContainer)
    }
}
