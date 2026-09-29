import SwiftUI
import SightglassCore

/// The live JSON outline; leaf checkboxes add/remove fields.
struct KeyTreeView: View {
    @Bindable var watch: Watch
    @Binding var selection: String?

    var body: some View {
        if let root = watch.state.value {
            List(JSONTree.nodes(for: root), children: \.children, selection: $selection) { node in
                KeyRow(node: node, watch: watch)
            }
        } else {
            ContentUnavailableView(watch.statusLine, systemImage: "doc.text.magnifyingglass")
        }
    }
}

private struct KeyRow: View {
    let node: JSONTreeNode
    @Bindable var watch: Watch

    var body: some View {
        HStack(spacing: 6) {
            if let value = node.leafValue {
                Toggle("Show \(node.title)", isOn: isShown(value))
                    .toggleStyle(.checkbox)
                    .labelsHidden()
            }
            Text(node.title)
                .foregroundStyle(node.id.hasSuffix("#more") ? HierarchicalShapeStyle.secondary : HierarchicalShapeStyle.primary)
            Spacer()
            Text(node.summary)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    /// On when the key has at least one field. Ticking adds a guessed field;
    /// unticking removes all of the key's fields.
    private func isShown(_ value: JSONValue) -> Binding<Bool> {
        Binding(
            get: { watch.config.fields.contains { $0.path == node.path } },
            set: { isOn in
                if isOn {
                    let guess = DisplayGuesser.guess(path: node.path, value: value)
                    watch.config.fields.append(FieldConfig(path: node.path, display: guess.display, format: guess.format))
                } else {
                    watch.config.fields.removeAll { $0.path == node.path }
                }
            }
        )
    }
}
