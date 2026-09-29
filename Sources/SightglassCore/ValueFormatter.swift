import Foundation

/// How a number is written.
public enum ValueFormat: Codable, Hashable, Sendable {
    case auto
    case integer
    case decimal(places: Int)
    case bytes
    case duration
}

public enum ValueFormatter {
    /// Formats a JSON value. Numbers (and, for non-auto formats, numeric
    /// strings) use `format`; everything else uses its display string.
    public static func string(for value: JSONValue, format: ValueFormat, locale: Locale = .current) -> String {
        switch value {
        case .number(let number):
            return string(for: number, format: format, locale: locale)
        case .string where format != .auto:
            guard let number = value.doubleValue else { return value.displayString }
            return string(for: number, format: format, locale: locale)
        default:
            return value.displayString
        }
    }

    public static func string(for number: Double, format: ValueFormat, locale: Locale = .current) -> String {
        switch format {
        case .auto:
            return number.formatted(.number.precision(.fractionLength(0...2)).locale(locale))
        case .integer:
            return number.formatted(.number.precision(.fractionLength(0)).locale(locale))
        case .decimal(let places):
            return number.formatted(.number.precision(.fractionLength(min(max(places, 0), 10))).locale(locale))
        case .bytes:
            return int64(number).formatted(.byteCount(style: .file, spellsOutZero: false).locale(locale))
        case .duration:
            return duration(number)
        }
    }

    /// A per-second rate: `3.4/s`, `12 files/s`, `3.4 MB/s`.
    public static func rate(_ perSecond: Double, format: ValueFormat, unit: String?, locale: Locale = .current) -> String {
        if format == .bytes {
            return "\(string(for: perSecond, format: .bytes, locale: locale))/s"
        }
        let magnitude = abs(perSecond)
        let style: FloatingPointFormatStyle<Double> =
            magnitude >= 100 ? .number.precision(.fractionLength(0))
            : magnitude >= 1 ? .number.precision(.fractionLength(0...1))
            : .number.precision(.significantDigits(1...2))
        let amount = perSecond.formatted(style.locale(locale))
        if let unit, !unit.isEmpty { return "\(amount) \(unit)/s" }
        return "\(amount)/s"
    }

    /// `45s`, `12m 03s`, `1h 02m`, `2d 03h`. Negative and non-finite values are 0.
    public static func duration(_ seconds: Double) -> String {
        let total = seconds.isFinite ? Int(min(max(seconds, 0), 1e12).rounded()) : 0
        let days = total / 86_400
        let hours = total % 86_400 / 3_600
        let minutes = total % 3_600 / 60
        let secs = total % 60
        if total < 60 { return "\(secs)s" }
        if total < 3_600 { return "\(minutes)m \(pad(secs))s" }
        if total < 86_400 { return "\(hours)h \(pad(minutes))m" }
        return "\(days)d \(pad(hours))h"
    }

    /// Like `duration` but drops seconds once past a minute: `45s`, `12m`, `1h 02m`.
    public static func shortDuration(_ seconds: Double) -> String {
        let total = seconds.isFinite ? Int(min(max(seconds, 0), 1e12).rounded()) : 0
        if total >= 60, total < 3_600 { return "\(total / 60)m" }
        return duration(seconds)
    }

    private static func pad(_ number: Int) -> String {
        number < 10 ? "0\(number)" : "\(number)"
    }

    private static func int64(_ number: Double) -> Int64 {
        guard number.isFinite else { return 0 }
        return Int64(min(max(number.rounded(), -9e18), 9e18))
    }
}
