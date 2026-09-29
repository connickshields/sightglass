import Foundation

/// Why a field can't show a value.
public enum FieldIssue: Equatable, Sendable {
    case noData
    case missing
    case notNumeric
    case noTotal

    public var message: String {
        switch self {
        case .noData: "Waiting for data"
        case .missing: "Key not found"
        case .notNumeric: "Expected a number"
        case .noTotal: "Total is missing or zero"
        }
    }
}

public struct ProgressInfo: Equatable, Sendable {
    public var value: Double
    /// Only set for ratio sources.
    public var total: Double?
    /// Unclamped; may exceed 1 when a job overshoots its total.
    public var fraction: Double

    public init(value: Double, total: Double?, fraction: Double) {
        self.value = value
        self.total = total
        self.fraction = fraction
    }

    /// For drawing bars and rings.
    public var clampedFraction: Double { min(max(fraction, 0), 1) }

    /// The true percentage, e.g. `42%` or `110%`.
    public var percentText: String {
        let percent = min(max((fraction * 100).rounded(), -1e9), 1e9)
        return "\(Int(percent))%"
    }
}

public struct RateInfo: Equatable, Sendable {
    public var value: Double
    public var perSecond: Double?
    public var total: Double?
    public var eta: TimeInterval?
    /// True while there are too few recent readings to estimate a rate yet.
    public var isMeasuring: Bool

    public init(value: Double, perSecond: Double?, total: Double?, eta: TimeInterval?, isMeasuring: Bool = false) {
        self.value = value
        self.perSecond = perSecond
        self.total = total
        self.eta = eta
        self.isMeasuring = isMeasuring
    }
}

/// Everything a view needs to draw one field.
public enum FieldState: Equatable, Sendable {
    case text(String)
    case progress(ProgressInfo)
    case sparkline([Double])
    case rate(RateInfo)
    case badge(BadgeRule, raw: String)
    case issue(FieldIssue)
}

public enum FieldEvaluator {
    public static func evaluate(_ field: FieldConfig, in root: JSONValue?, history: History, now: Date, locale: Locale = .current) -> FieldState {
        guard let root else { return .issue(.noData) }
        guard let value = root[field.path] else { return .issue(.missing) }

        switch field.display {
        case .text:
            return .text(ValueFormatter.string(for: value, format: field.format, locale: locale))

        case .badge(let rules):
            return .badge(BadgeRule.firstMatch(for: value, in: rules) ?? .fallback, raw: value.displayString)

        case .percent(let source), .bar(let source, _), .ring(let source, _):
            guard let number = value.doubleValue else { return .issue(.notNumeric) }
            switch source {
            case .fraction:
                return .progress(ProgressInfo(value: number, total: nil, fraction: number))
            case .percentage:
                return .progress(ProgressInfo(value: number, total: nil, fraction: number / 100))
            case .ratio(let totalPath):
                guard let total = root[totalPath]?.doubleValue, total != 0 else { return .issue(.noTotal) }
                return .progress(ProgressInfo(value: number, total: total, fraction: number / total))
            }

        case .sparkline(let samples):
            guard let number = value.doubleValue else { return .issue(.notNumeric) }
            let values = history.recentValues(samples)
            return .sparkline(values.isEmpty ? [number] : values)

        case .rate(let totalPath, _):
            guard let number = value.doubleValue else { return .issue(.notNumeric) }
            let perSecond = RateEstimator.rate(from: history.samples, now: now)
            let total = totalPath.flatMap { root[$0]?.doubleValue }
            let eta = perSecond.flatMap { rate in
                total.flatMap { RateEstimator.eta(value: number, total: $0, rate: rate) }
            }
            // Still warming up: few timed readings, and the first one is recent.
            let timed = history.samples.compactMap(\.date)
            let isMeasuring = perSecond == nil
                && timed.count < RateEstimator.minSamples
                && (timed.first.map { now.timeIntervalSince($0) <= RateEstimator.window } ?? true)
            return .rate(RateInfo(value: number, perSecond: perSecond, total: total, eta: eta, isMeasuring: isMeasuring))
        }
    }
}
