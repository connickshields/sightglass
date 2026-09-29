import SwiftUI
import SightglassCore

/// Name and staleness on top, key tree | field editor in the middle,
/// live preview strip at the bottom. Every edit saves immediately.
struct ConfigureView: View {
    @Bindable var watch: Watch
    var setTitle: (String) -> Void
    @State private var selection: String?

    private static let staleChoices: [Int] = [1, 2, 5, 10, 30, 60]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                TextField("Name", text: $watch.config.name)
                    .frame(maxWidth: 280)
                Picker("Stale after", selection: $watch.config.staleAfter) {
                    Text("Off").tag(TimeInterval?.none)
                    ForEach(Self.staleChoices, id: \.self) { minutes in
                        Text("\(minutes) min").tag(TimeInterval?.some(TimeInterval(minutes * 60)))
                    }
                }
                .frame(maxWidth: 200)
                Spacer()
            }
            .padding(12)
            Divider()
            HSplitView {
                KeyTreeView(watch: watch, selection: $selection)
                    .frame(minWidth: 280, idealWidth: 340, maxHeight: .infinity)
                FieldEditorView(watch: watch, path: selection.flatMap { try? FieldPath(parsing: $0) })
                    .frame(minWidth: 320, maxHeight: .infinity)
            }
            Divider()
            PreviewStrip(watch: watch, selection: $selection)
                .padding(12)
        }
        .frame(minWidth: 640, minHeight: 400)
        .onChange(of: watch.config.name, initial: true) { _, name in
            setTitle("Configure: \(name)")
        }
    }
}
