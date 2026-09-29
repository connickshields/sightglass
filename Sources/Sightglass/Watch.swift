import Foundation
import Observation
import SightglassCore

/// One watched file: its settings plus live state.
@MainActor @Observable
final class Watch: Identifiable {
    let id: UUID
    var config: WatchConfig {
        didSet { if config != oldValue { onConfigChange?(self) } }
    }
    private(set) var state = WatchState()
    /// Advanced by WatchManager's clock so relative times and rates refresh.
    private(set) var now = Date()

    @ObservationIgnored var onConfigChange: ((Watch) -> Void)?
    @ObservationIgnored private var engine: WatchEngine?

    init(config: WatchConfig) {
        id = config.id
        self.config = config
    }

    func start() {
        let engine = WatchEngine(url: config.url, callbackQueue: .main) { [weak self] update in
            MainActor.assumeIsolated { self?.apply(update) }
        }
        engine.start()
        self.engine = engine
    }

    func stop() {
        engine?.stop()
        engine = nil
    }

    func tick(_ date: Date) {
        now = date
    }

    func fieldState(_ field: FieldConfig) -> FieldState {
        FieldEvaluator.evaluate(field, in: state.value, history: state.history(for: field.path), now: now)
    }

    var needsAttention: Bool { state.needsAttention(now: now, staleAfter: config.staleAfter) }
    var statusLine: String { state.statusLine(now: now, staleAfter: config.staleAfter) }

    private func apply(_ update: WatchUpdate) {
        now = Date()
        state.apply(update, trackedPaths: config.trackedPaths, now: now)
    }
}
