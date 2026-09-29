import Foundation

/// A parsed JSON value.
public enum JSONValue: Equatable, Sendable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    /// Parses JSON data. Top-level scalars are allowed.
    public static func parse(_ data: Data) throws -> JSONValue {
        let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        return JSONValue(foundation: object)
    }

    /// Converts `JSONSerialization` output.
    init(foundation object: Any) {
        switch object {
        case let dictionary as [String: Any]:
            self = .object(dictionary.mapValues(JSONValue.init(foundation:)))
        case let array as [Any]:
            self = .array(array.map(JSONValue.init(foundation:)))
        case let string as String:
            self = .string(string)
        case let number as NSNumber:
            // JSONSerialization returns NSNumber for both; CFBoolean tells them apart.
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                self = .bool(number.boolValue)
            } else {
                self = .number(number.doubleValue)
            }
        default:
            self = .null
        }
    }

    /// The value as a number. Accepts numbers and numeric strings (some tools
    /// write `"42"`), but not bools.
    public var doubleValue: Double? {
        switch self {
        case .number(let number):
            return number
        case .string(let string):
            guard let number = Double(string.trimmingCharacters(in: .whitespaces)), number.isFinite else { return nil }
            return number
        default:
            return nil
        }
    }

    /// A short, locale-independent form used for raw values and badge matching.
    public var displayString: String {
        switch self {
        case .string(let string): string
        case .number(let number): Self.plain(number)
        case .bool(let bool): bool ? "true" : "false"
        case .null: "null"
        case .array(let array): array.count == 1 ? "[1 item]" : "[\(array.count) items]"
        case .object(let object): object.count == 1 ? "{1 key}" : "{\(object.count) keys}"
        }
    }

    public var isContainer: Bool {
        switch self {
        case .object, .array: true
        default: false
        }
    }

    private static func plain(_ number: Double) -> String {
        if number.rounded() == number, abs(number) < 1e15 { return String(Int64(number)) }
        return String(number)
    }
}
