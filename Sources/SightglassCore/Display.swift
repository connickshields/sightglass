import Foundation

/// How to turn a field's number into a 0…1 fraction.
public enum ProgressSource: Codable, Hashable, Sendable {
    /// value ÷ the number at `total`.
    case ratio(total: FieldPath)
    /// The value is already 0…1.
    case fraction
    /// The value is 0…100.
    case percentage
}

public enum BadgeColor: String, Codable, CaseIterable, Sendable {
    case blue, green, red, orange, yellow, gray, primary
}

/// Shows `symbol` in `color` when a value equals `match` (case-insensitive).
public struct BadgeRule: Codable, Hashable, Sendable {
    public var match: String
    public var symbol: String
    public var color: BadgeColor

    public init(match: String, symbol: String, color: BadgeColor) {
        self.match = match
        self.symbol = symbol
        self.color = color
    }

    /// Shown when no rule matches.
    public static let fallback = BadgeRule(match: "", symbol: "questionmark.circle", color: .gray)

    public static let defaults: [BadgeRule] = {
        func rules(_ words: [String], _ symbol: String, _ color: BadgeColor) -> [BadgeRule] {
            words.map { BadgeRule(match: $0, symbol: symbol, color: color) }
        }
        return rules(["running", "in_progress"], "circle.fill", .blue)
            + rules(["done", "complete", "completed", "success", "true"], "checkmark.circle.fill", .green)
            + rules(["error", "failed", "failure", "false"], "xmark.octagon.fill", .red)
            + rules(["pending", "queued", "waiting"], "clock", .gray)
    }()

    /// The first rule matching the value's display string, if any.
    public static func firstMatch(for value: JSONValue, in rules: [BadgeRule]) -> BadgeRule? {
        let text = value.displayString.trimmingCharacters(in: .whitespaces)
        return rules.first { $0.match.caseInsensitiveCompare(text) == .orderedSame }
    }
}

/// How one field is drawn.
public enum Display: Codable, Hashable, Sendable {
    case text
    case percent(source: ProgressSource)
    case bar(source: ProgressSource, showsPercent: Bool)
    case ring(source: ProgressSource, showsPercent: Bool)
    case sparkline(samples: Int)
    case rate(total: FieldPath?, unit: String?)
    case badge(rules: [BadgeRule])

    public var kind: DisplayKind {
        switch self {
        case .text: .text
        case .percent: .percent
        case .bar: .bar
        case .ring: .ring
        case .sparkline: .sparkline
        case .rate: .rate
        case .badge: .badge
        }
    }

    // Accessors for editing one option in place. Setters only apply to the
    // cases that have that option.

    public var progressSource: ProgressSource? {
        get {
            switch self {
            case .percent(let source), .bar(let source, _), .ring(let source, _): source
            default: nil
            }
        }
        set {
            guard let newValue else { return }
            switch self {
            case .percent: self = .percent(source: newValue)
            case .bar(_, let showsPercent): self = .bar(source: newValue, showsPercent: showsPercent)
            case .ring(_, let showsPercent): self = .ring(source: newValue, showsPercent: showsPercent)
            default: break
            }
        }
    }

    public var showsPercent: Bool {
        get {
            switch self {
            case .bar(_, let showsPercent), .ring(_, let showsPercent): showsPercent
            case .percent: true
            default: false
            }
        }
        set {
            switch self {
            case .bar(let source, _): self = .bar(source: source, showsPercent: newValue)
            case .ring(let source, _): self = .ring(source: source, showsPercent: newValue)
            default: break
            }
        }
    }

    public var sparklineSamples: Int {
        get { if case .sparkline(let samples) = self { samples } else { 60 } }
        set { if case .sparkline = self { self = .sparkline(samples: newValue) } }
    }

    public var rateTotal: FieldPath? {
        get { if case .rate(let total, _) = self { total } else { nil } }
        set { if case .rate(_, let unit) = self { self = .rate(total: newValue, unit: unit) } }
    }

    public var rateUnit: String? {
        get { if case .rate(_, let unit) = self { unit } else { nil } }
        set { if case .rate(let total, _) = self { self = .rate(total: total, unit: newValue) } }
    }

    public var badgeRules: [BadgeRule] {
        get { if case .badge(let rules) = self { rules } else { [] } }
        set { if case .badge = self { self = .badge(rules: newValue) } }
    }
}

public enum DisplayKind: String, CaseIterable, Identifiable, Sendable {
    case text, percent, bar, ring, sparkline, rate, badge

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .text: "Text"
        case .percent: "Percent"
        case .bar: "Progress Bar"
        case .ring: "Progress Ring"
        case .sparkline: "Sparkline"
        case .rate: "Rate + ETA"
        case .badge: "Status Badge"
        }
    }
}

/// One thing shown for a watch.
public struct FieldConfig: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var path: FieldPath
    public var label: String?
    public var display: Display
    public var format: ValueFormat

    public init(id: UUID = UUID(), path: FieldPath, label: String? = nil, display: Display = .text, format: ValueFormat = .auto) {
        self.id = id
        self.path = path
        self.label = label
        self.display = display
        self.format = format
    }

    /// The label, or the path when there's no label.
    public var title: String {
        if let label, !label.isEmpty { return label }
        return path.description
    }
}
