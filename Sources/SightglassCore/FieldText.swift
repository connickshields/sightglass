import Foundation

/// Text pieces shared by the menu bar and menu views.
public enum FieldText {
    /// `3.4/s · 12m`, `3.4/s` without an ETA, or `–/s` without a rate.
    public static func compactRate(_ info: RateInfo, format: ValueFormat, unit: String?, locale: Locale = .current) -> String {
        guard let perSecond = info.perSecond else { return "–/s" }
        let rate = ValueFormatter.rate(perSecond, format: format, unit: unit, locale: locale)
        guard let eta = info.eta else { return rate }
        return "\(rate) · \(ValueFormatter.shortDuration(eta))"
    }

    /// `3.4/s · 12m 03s left · finishes 3:41 PM`, or `No recent progress`.
    public static func expandedRate(_ info: RateInfo, format: ValueFormat, unit: String?, now: Date, locale: Locale = .current) -> String {
        guard let perSecond = info.perSecond else { return "No recent progress" }
        var parts = [ValueFormatter.rate(perSecond, format: format, unit: unit, locale: locale)]
        if let eta = info.eta {
            parts.append("\(ValueFormatter.duration(eta)) left")
            let finish = now.addingTimeInterval(eta).formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale))
            parts.append("finishes \(finish)")
        }
        return parts.joined(separator: " · ")
    }

    /// `42% (420 / 1,000)` for ratios, `42%` otherwise.
    public static func progressDetail(_ info: ProgressInfo, format: ValueFormat, locale: Locale = .current) -> String {
        guard let total = info.total else { return info.percentText }
        let value = ValueFormatter.string(for: info.value, format: format, locale: locale)
        let totalText = ValueFormatter.string(for: total, format: format, locale: locale)
        return "\(info.percentText) (\(value) / \(totalText))"
    }

    /// `min 3 · max 42 · now 40`, or empty without values.
    public static func sparklineDetail(_ values: [Double], format: ValueFormat, locale: Locale = .current) -> String {
        guard let low = values.min(), let high = values.max(), let last = values.last else { return "" }
        func text(_ number: Double) -> String { ValueFormatter.string(for: number, format: format, locale: locale) }
        return "min \(text(low)) · max \(text(high)) · now \(text(last))"
    }
}
