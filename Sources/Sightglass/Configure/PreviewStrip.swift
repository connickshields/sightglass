import SwiftUI
import SightglassCore

/// The fields as they appear in the menu bar. Click to select, drag to reorder.
struct PreviewStrip: View {
    @Bindable var watch: Watch
    @Binding var selection: String?

    var body: some View {
        HStack(spacing: 8) {
            Text("Preview").foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if watch.config.fields.isEmpty {
                        Text("Tick keys to add them to the menu bar.").foregroundStyle(.secondary)
                    }
                    ForEach(watch.config.fields) { field in
                        chip(for: field)
                    }
                }
            }
            Text("Drag to reorder").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func chip(for field: FieldConfig) -> some View {
        let isSelected = selection == field.path.description
        return CompactFieldView(field: field, state: watch.fieldState(field))
            .font(.system(size: 13).monospacedDigit())
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.08))
            )
            .contentShape(Rectangle())
            .onTapGesture { selection = field.path.description }
            .draggable(field.id.uuidString)
            .dropDestination(for: String.self) { items, _ in
                move(items.first, onto: field.id)
            }
    }

    /// Moves the dragged field to the target's position.
    private func move(_ idString: String?, onto target: UUID) -> Bool {
        guard let idString, let id = UUID(uuidString: idString), id != target,
              let from = watch.config.fields.firstIndex(where: { $0.id == id }),
              let to = watch.config.fields.firstIndex(where: { $0.id == target }) else { return false }
        watch.config.fields.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        return true
    }
}
