import Foundation

/// Picks sensible defaults when the user ticks a key or changes its display.
public enum DisplayGuesser {
    /// The display and format for a newly ticked leaf (spec §3.5).
    public static func guess(path: FieldPath, value: JSONValue) -> (display: Display, format: ValueFormat) {
        let key = path.lastKey?.lowercased() ?? ""
        switch value {
        case .string, .bool:
            if BadgeRule.firstMatch(for: value, in: BadgeRule.defaults) != nil {
                return (.badge(rules: BadgeRule.defaults), .auto)
            }
            return (.text, .auto)
        case .number(let number):
            if isPercentKey(path) {
                return (.percent(source: number <= 1 ? .fraction : .percentage), .auto)
            }
            if key.contains("bytes") || key.contains("size") {
                return (.text, .bytes)
            }
            return (.text, .auto)
        default:
            return (.text, .auto)
        }
    }

    /// The display to use when the user picks `kind` for the field at `path`.
    public static func display(for kind: DisplayKind, path: FieldPath, in root: JSONValue?) -> Display {
        let total = totalPath(for: path, in: root)
        let source = progressSource(for: path, in: root, total: total)
        switch kind {
        case .text: return .text
        case .percent: return .percent(source: source)
        case .bar: return .bar(source: source, showsPercent: true)
        case .ring: return .ring(source: source, showsPercent: false)
        case .sparkline: return .sparkline(samples: 60)
        case .rate: return .rate(total: total, unit: nil)
        case .badge: return .badge(rules: BadgeRule.defaults)
        }
    }

    /// A numeric sibling whose key contains "total" (e.g. `progress.total`,
    /// `total_files`), excluding `path` itself.
    public static func totalPath(for path: FieldPath, in root: JSONValue?) -> FieldPath? {
        guard let root, let parent = path.parent, case .object(let siblings)? = root[parent] else { return nil }
        return siblings.keys.sorted()
            .filter { $0.lowercased().contains("total") && siblings[$0]?.doubleValue != nil }
            .map { parent.appending(.key($0)) }
            .first { $0 != path }
    }

    private static func progressSource(for path: FieldPath, in root: JSONValue?, total: FieldPath?) -> ProgressSource {
        if !isPercentKey(path), let total { return .ratio(total: total) }
        let value = root?[path]?.doubleValue ?? 0
        return value <= 1 ? .fraction : .percentage
    }

    private static func isPercentKey(_ path: FieldPath) -> Bool {
        let key = path.lastKey?.lowercased() ?? ""
        return key.contains("percent") || key.contains("progress")
    }
}
