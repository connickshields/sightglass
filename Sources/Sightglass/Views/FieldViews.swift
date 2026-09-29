import SwiftUI
import SightglassCore

extension BadgeColor {
    var color: Color {
        switch self {
        case .blue: .blue
        case .green: .green
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .gray: .gray
        case .primary: .primary
        }
    }
}

/// One field as shown in the menu bar.
struct CompactFieldView: View {
    let field: FieldConfig
    let state: FieldState

    var body: some View {
        HStack(spacing: 3) {
            if let label = field.label, !label.isEmpty {
                Text(label).foregroundStyle(.secondary)
            }
            content
        }
    }

    @ViewBuilder private var content: some View {
        switch state {
        case .text(let text):
            Text(text)
        case .progress(let info):
            switch field.display {
            case .bar(_, let showsPercent):
                ProgressBar(fraction: info.clampedFraction).frame(width: 36, height: 6)
                if showsPercent { Text(info.percentText) }
            case .ring(_, let showsPercent):
                ProgressRing(fraction: info.clampedFraction, lineWidth: 2.5).frame(width: 14, height: 14)
                if showsPercent { Text(info.percentText) }
            default:
                Text(info.percentText)
            }
        case .sparkline(let values):
            Sparkline(values: values).frame(width: 40, height: 14)
        case .rate(let info):
            Text(FieldText.compactRate(info, format: field.format, unit: field.display.rateUnit))
        case .badge(let rule, _):
            Image(systemName: rule.symbol).foregroundStyle(rule.color.color)
        case .issue:
            Text("–")
        }
    }
}

/// One field as shown in the dropdown menu: larger, with numbers.
struct ExpandedFieldView: View {
    let field: FieldConfig
    let state: FieldState
    let now: Date

    var body: some View {
        switch state {
        case .text(let text):
            Text(text)
        case .progress(let info):
            HStack(spacing: 8) {
                switch field.display {
                case .bar:
                    ProgressBar(fraction: info.clampedFraction).frame(width: 120, height: 8)
                case .ring:
                    ProgressRing(fraction: info.clampedFraction, lineWidth: 4).frame(width: 28, height: 28)
                default:
                    EmptyView()
                }
                Text(FieldText.progressDetail(info, format: field.format))
            }
        case .sparkline(let values):
            VStack(alignment: .leading, spacing: 2) {
                Sparkline(values: values).frame(width: 160, height: 28)
                Text(FieldText.sparklineDetail(values, format: field.format))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .rate(let info):
            Text(FieldText.expandedRate(info, format: field.format, unit: field.display.rateUnit, now: now))
        case .badge(let rule, let raw):
            HStack(spacing: 4) {
                Image(systemName: rule.symbol).foregroundStyle(rule.color.color)
                Text(raw)
            }
        case .issue(let issue):
            Text("– \(issue.message)").foregroundStyle(.secondary)
        }
    }
}

struct ProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.25))
                Capsule().fill(.primary).frame(width: proxy.size.width * fraction)
            }
        }
    }
}

struct ProgressRing: View {
    let fraction: Double
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(.primary.opacity(0.25), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(.primary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
    }
}

struct Sparkline: View {
    let values: [Double]

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                guard let low = values.min(), let high = values.max() else { return }
                let span = high - low
                let step = values.count > 1 ? proxy.size.width / CGFloat(values.count - 1) : 0
                for (index, value) in values.enumerated() {
                    let y = span > 0 ? 1 - (value - low) / span : 0.5
                    let point = CGPoint(x: CGFloat(index) * step, y: CGFloat(y) * proxy.size.height)
                    if index == 0 {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }
                if values.count == 1 {
                    path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height / 2))
                }
            }
            .stroke(.primary, style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round))
        }
    }
}
