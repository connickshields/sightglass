import SwiftUI
import SightglassCore

/// The header and field list at the top of a watch's menu.
struct MenuDetailView: View {
    let watch: Watch

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(watch.config.name).font(.headline)
                Text((watch.config.path as NSString).abbreviatingWithTildeInPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    if watch.needsAttention {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                    Text(watch.statusLine).fixedSize(horizontal: false, vertical: true)
                }
                .font(.caption)
                .foregroundStyle(watch.needsAttention ? HierarchicalShapeStyle.primary : HierarchicalShapeStyle.secondary)
            }
            if !watch.config.fields.isEmpty {
                Divider()
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    ForEach(watch.config.fields) { field in
                        GridRow {
                            Text(field.title).foregroundStyle(.secondary).lineLimit(1)
                            ExpandedFieldView(field: field, state: watch.fieldState(field), now: watch.now)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(width: 320, alignment: .leading)
    }
}
