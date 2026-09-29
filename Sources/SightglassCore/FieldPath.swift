import Foundation

/// A location inside a JSON value, written like `stats.files[0].bytes`.
/// Keys that aren't plain identifiers use bracket-quote form: `["a.b"]`.
public struct FieldPath: Hashable, Sendable, Comparable, CustomStringConvertible {
    public enum Component: Hashable, Sendable {
        case key(String)
        case index(Int)
    }

    public struct ParseError: Error, Equatable {
        public let position: Int
    }

    public var components: [Component]

    public init(_ components: [Component] = []) {
        self.components = components
    }

    public static let root = FieldPath()

    public func appending(_ component: Component) -> FieldPath {
        FieldPath(components + [component])
    }

    /// The last object key in the path, if any.
    public var lastKey: String? {
        for component in components.reversed() {
            if case .key(let key) = component { return key }
        }
        return nil
    }

    /// The path without its last component; nil for the root.
    public var parent: FieldPath? {
        components.isEmpty ? nil : FieldPath(Array(components.dropLast()))
    }

    public var description: String {
        var result = ""
        for component in components {
            switch component {
            case .index(let index):
                result += "[\(index)]"
            case .key(let key) where Self.isPlain(key):
                result += result.isEmpty ? key : ".\(key)"
            case .key(let key):
                var escaped = String.UnicodeScalarView()
                for scalar in key.unicodeScalars {
                    if scalar == "\\" || scalar == "\"" { escaped.append("\\") }
                    escaped.append(scalar)
                }
                result += "[\"\(String(escaped))\"]"
            }
        }
        return result
    }

    public static func < (lhs: FieldPath, rhs: FieldPath) -> Bool {
        lhs.description < rhs.description
    }

    /// Parses the form produced by `description`.
    public init(parsing string: String) throws {
        // Scalars, not Characters: a key starting with a combining mark would otherwise fuse with the preceding bracket.
        let chars = Array(string.unicodeScalars)
        var i = 0
        var components: [Component] = []

        func plainKey() throws -> String {
            let start = i
            while i < chars.count, Self.isPlain(chars[i]) { i += 1 }
            guard i > start else { throw ParseError(position: start) }
            return Self.string(chars[start..<i])
        }

        while i < chars.count {
            switch chars[i] {
            case "[":
                i += 1
                if i < chars.count, chars[i] == "\"" {
                    i += 1
                    var key = ""
                    scan: while true {
                        guard i < chars.count else { throw ParseError(position: i) }
                        switch chars[i] {
                        case "\\":
                            guard i + 1 < chars.count else { throw ParseError(position: i) }
                            key.unicodeScalars.append(chars[i + 1])
                            i += 2
                        case "\"":
                            i += 1
                            break scan
                        default:
                            key.unicodeScalars.append(chars[i])
                            i += 1
                        }
                    }
                    guard i < chars.count, chars[i] == "]" else { throw ParseError(position: i) }
                    i += 1
                    components.append(.key(key))
                } else {
                    let start = i
                    while i < chars.count, chars[i].value >= 0x30, chars[i].value <= 0x39 { i += 1 }
                    guard i > start, i < chars.count, chars[i] == "]",
                          let index = Int(Self.string(chars[start..<i])) else { throw ParseError(position: start) }
                    i += 1
                    components.append(.index(index))
                }
            case ".":
                guard !components.isEmpty else { throw ParseError(position: i) }
                i += 1
                components.append(.key(try plainKey()))
            default:
                guard components.isEmpty else { throw ParseError(position: i) }
                components.append(.key(try plainKey()))
            }
        }
        self.components = components
    }

    private static let plainCharacters = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-".unicodeScalars)

    private static func isPlain(_ scalar: Unicode.Scalar) -> Bool {
        plainCharacters.contains(scalar)
    }

    private static func string(_ scalars: ArraySlice<Unicode.Scalar>) -> String {
        var result = String.UnicodeScalarView()
        result.append(contentsOf: scalars)
        return String(result)
    }

    static func isPlain(_ key: String) -> Bool {
        !key.isEmpty && key.unicodeScalars.allSatisfy(isPlain)
    }
}

extension FieldPath: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let path = try? FieldPath(parsing: string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid field path: \(string)")
        }
        self = path
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

extension JSONValue {
    /// The value at `path`, or nil if any step doesn't exist.
    public subscript(path: FieldPath) -> JSONValue? {
        var current = self
        for component in path.components {
            switch (component, current) {
            case (.key(let key), .object(let object)):
                guard let next = object[key] else { return nil }
                current = next
            case (.index(let index), .array(let array)):
                guard array.indices.contains(index) else { return nil }
                current = array[index]
            default:
                return nil
            }
        }
        return current
    }
}
