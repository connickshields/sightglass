import SwiftUI
import SightglassCore

/// The compact menu bar rendering of a watch.
struct StatusItemView: View {
    let watch: Watch
    var onWidthChange: (CGFloat) -> Void = { _ in }

    private var displayName: String {
        let name = watch.config.name
        return name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? watch.config.url.lastPathComponent : name
    }

    var body: some View {
        HStack(spacing: 6) {
            if watch.needsAttention {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }
            if watch.config.fields.isEmpty || watch.state.value == nil {
                Text(displayName).lineLimit(1).truncationMode(.tail).frame(maxWidth: 160)
            } else {
                HStack(spacing: 6) {
                    ForEach(watch.config.fields) { field in
                        CompactFieldView(field: field, state: watch.fieldState(field))
                    }
                }
                .opacity(watch.needsAttention ? 0.5 : 1)
            }
        }
        .font(.system(size: 13).monospacedDigit())
        .padding(.horizontal, 6)
        .fixedSize()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { onWidthChange($0) }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
