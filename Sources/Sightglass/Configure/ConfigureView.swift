import SwiftUI
import SightglassCore

/// Name and staleness on top, key tree | field editor in the middle,
/// live preview strip at the bottom. Every edit saves immediately.
struct ConfigureView: View {
    @Bindable var watch: Watch
    var setTitle: (String) -> Void
    @State private var selection: String?

    private static let staleChoices: [TimeInterval] = [1, 2, 5, 10, 30, 60].map { TimeInterval($0 * 60) }

    /// The presets, plus the current value when it isn't one of them, so the picker is never blank.
    private var staleOptions: [TimeInterval] {
        guard let current = watch.config.staleAfter, !Self.staleChoices.contains(current) else { return Self.staleChoices }
        return (Self.staleChoices + [current]).sorted()
    }

    private static func staleLabel(_ seconds: TimeInterval) -> String {
        let whole = Int(seconds)
        return whole >= 60 && whole % 60 == 0 ? "\(whole / 60) min" : "\(whole) s"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                TextField("Name", text: $watch.config.name)
                    .frame(maxWidth: 280)
                Picker("Stale after", selection: $watch.config.staleAfter) {
                    Text("Off").tag(TimeInterval?.none)
                    ForEach(staleOptions, id: \.self) { seconds in
                        Text(Self.staleLabel(seconds)).tag(TimeInterval?.some(seconds))
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
