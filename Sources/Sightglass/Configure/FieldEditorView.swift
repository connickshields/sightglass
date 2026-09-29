import SwiftUI
import SightglassCore

/// Edits every field shown for the selected key.
struct FieldEditorView: View {
    @Bindable var watch: Watch
    let path: FieldPath?

    var body: some View {
        if let path, watch.state.value?[path]?.isContainer != true {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(path.description).font(.headline)
                    ForEach(watch.config.fields.filter { $0.path == path }) { field in
                        FieldForm(field: binding(for: field), root: watch.state.value) {
                            watch.config.fields.removeAll { $0.id == field.id }
                        }
                    }
                    Button("Add Display") { add(path) }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            ContentUnavailableView(
                "Select a value",
                systemImage: "cursorarrow.click",
                description: Text("Tick keys on the left to show them in the menu bar.")
            )
        }
    }

    /// Binds by id so removing a field never leaves a stale index behind.
    private func binding(for field: FieldConfig) -> Binding<FieldConfig> {
        Binding(
            get: { watch.config.fields.first { $0.id == field.id } ?? field },
            set: { newValue in
                if let index = watch.config.fields.firstIndex(where: { $0.id == field.id }) {
                    watch.config.fields[index] = newValue
                }
            }
        )
    }

    private func add(_ path: FieldPath) {
        let guess = DisplayGuesser.guess(path: path, value: watch.state.value?[path] ?? .null)
        watch.config.fields.append(FieldConfig(path: path, display: guess.display, format: guess.format))
    }
}

private struct FieldForm: View {
    @Binding var field: FieldConfig
    let root: JSONValue?
    let onRemove: () -> Void

    private enum SourceKind: Hashable { case ratio, fraction, percentage }

    var body: some View {
        GroupBox {
            Form {
                TextField("Label", text: optionalText(\.label))
                Picker("Display", selection: kind) {
                    ForEach(DisplayKind.allCases) { Text($0.title).tag($0) }
                }
                options
                if field.display.kind != .badge {
                    FormatPicker(format: $field.format)
                }
            }
            HStack {
                Spacer()
                Button("Remove Display", role: .destructive, action: onRemove)
            }
        }
    }

    @ViewBuilder private var options: some View {
        switch field.display.kind {
        case .percent, .bar, .ring:
            Picker("Source", selection: sourceKind) {
                Text("Value ÷ Total").tag(SourceKind.ratio)
                Text("Fraction (0–1)").tag(SourceKind.fraction)
                Text("Percentage (0–100)").tag(SourceKind.percentage)
            }
            if case .ratio? = field.display.progressSource {
                PathPicker(title: "Total", selection: ratioTotal, paths: numericPaths, allowsNone: false)
            }
            if field.display.kind != .percent {
                Toggle("Show percent", isOn: $field.display.showsPercent)
            }
        case .sparkline:
            Stepper("Samples: \(field.display.sparklineSamples)", value: $field.display.sparklineSamples, in: 10...300, step: 10)
        case .rate:
            PathPicker(title: "Total", selection: $field.display.rateTotal, paths: numericPaths, allowsNone: true)
            TextField("Unit", text: Binding(
                get: { field.display.rateUnit ?? "" },
                set: { field.display.rateUnit = $0.isEmpty ? nil : $0 }
            ))
        case .badge:
            LabeledContent("Rules") {
                BadgeRulesEditor(rules: $field.display.badgeRules)
            }
        case .text:
            EmptyView()
        }
    }

    private var numericPaths: [FieldPath] {
        JSONTree.numericLeafPaths(in: root).filter { $0 != field.path }
    }

    private var kind: Binding<DisplayKind> {
        Binding(
            get: { field.display.kind },
            set: { field.display = DisplayGuesser.display(for: $0, path: field.path, in: root) }
        )
    }

    private var sourceKind: Binding<SourceKind> {
        Binding(
            get: {
                switch field.display.progressSource {
                case .ratio?: .ratio
                case .percentage?: .percentage
                default: .fraction
                }
            },
            set: { newKind in
                switch newKind {
                case .fraction: field.display.progressSource = .fraction
                case .percentage: field.display.progressSource = .percentage
                case .ratio:
                    let total = DisplayGuesser.totalPath(for: field.path, in: root) ?? numericPaths.first ?? field.path
                    field.display.progressSource = .ratio(total: total)
                }
            }
        )
    }

    private var ratioTotal: Binding<FieldPath?> {
        Binding(
            get: {
                if case .ratio(let total)? = field.display.progressSource { total } else { nil }
            },
            set: { newValue in
                if let newValue { field.display.progressSource = .ratio(total: newValue) }
            }
        )
    }

    private func optionalText(_ keyPath: WritableKeyPath<FieldConfig, String?>) -> Binding<String> {
        Binding(
            get: { field[keyPath: keyPath] ?? "" },
            set: { field[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }
}

private struct PathPicker: View {
    let title: String
    @Binding var selection: FieldPath?
    let paths: [FieldPath]
    let allowsNone: Bool

    var body: some View {
        Picker(title, selection: $selection) {
            if allowsNone { Text("None").tag(FieldPath?.none) }
            ForEach(options, id: \.self) { path in
                Text(path.description).tag(FieldPath?.some(path))
            }
        }
    }

    /// Keeps the current choice listed even if the file doesn't have it right now.
    private var options: [FieldPath] {
        guard let selection, !paths.contains(selection) else { return paths }
        return paths + [selection]
    }
}

private struct FormatPicker: View {
    @Binding var format: ValueFormat

    private enum Kind: Hashable { case auto, integer, decimal, bytes, duration }

    var body: some View {
        Picker("Format", selection: kind) {
            Text("Automatic").tag(Kind.auto)
            Text("Integer").tag(Kind.integer)
            Text("Decimal").tag(Kind.decimal)
            Text("Bytes").tag(Kind.bytes)
            Text("Duration").tag(Kind.duration)
        }
        if case .decimal(let places) = format {
            Stepper("Decimal places: \(places)", value: Binding(
                get: { places },
                set: { format = .decimal(places: $0) }
            ), in: 0...6)
        }
    }

    private var kind: Binding<Kind> {
        Binding(
            get: {
                switch format {
                case .auto: .auto
                case .integer: .integer
                case .decimal: .decimal
                case .bytes: .bytes
                case .duration: .duration
                }
            },
            set: { newKind in
                switch newKind {
                case .auto: format = .auto
                case .integer: format = .integer
                case .decimal: format = .decimal(places: 2)
                case .bytes: format = .bytes
                case .duration: format = .duration
                }
            }
        )
    }
}

private struct BadgeRulesEditor: View {
    @Binding var rules: [BadgeRule]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(rules.indices, id: \.self) { index in
                HStack(spacing: 6) {
                    TextField("Value", text: rule(index, \.match)).frame(width: 110)
                    TextField("SF Symbol", text: rule(index, \.symbol)).frame(width: 150)
                    Image(systemName: rules.indices.contains(index) ? rules[index].symbol : "questionmark")
                        .foregroundStyle((rules.indices.contains(index) ? rules[index].color : .gray).color)
                        .frame(width: 18)
                    Picker("Color", selection: rule(index, \.color)) {
                        ForEach(BadgeColor.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 90)
                    Button {
                        if rules.indices.contains(index) { rules.remove(at: index) }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }
            HStack {
                Button("Add Rule") { rules.append(BadgeRule(match: "", symbol: "circle.fill", color: .gray)) }
                Button("Reset to Defaults") { rules = BadgeRule.defaults }
            }
        }
    }

    /// Index-based binding that tolerates the row having just been removed.
    private func rule<Value>(_ index: Int, _ keyPath: WritableKeyPath<BadgeRule, Value>) -> Binding<Value> {
        Binding(
            get: { (rules.indices.contains(index) ? rules[index] : BadgeRule.fallback)[keyPath: keyPath] },
            set: { if rules.indices.contains(index) { rules[index][keyPath: keyPath] = $0 } }
        )
    }
}
