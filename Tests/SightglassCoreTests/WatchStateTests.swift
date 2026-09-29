import Foundation
import Testing
@testable import SightglassCore

struct WatchStateTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)
    let tracked: Set<FieldPath> = [fp("n")]

    func obj(_ n: Double) -> JSONValue { .object(["n": .number(n)]) }

    func update(_ value: JSONValue, seed: [JSONValue] = [], restart: Bool = false, modified: Date? = nil) -> WatchUpdate {
        WatchUpdate(status: .ok, snapshot: Snapshot(value: value, format: .ndjson, seed: seed, isRestart: restart), modified: modified)
    }

    @Test func recordsTrackedNumbers() {
        var state = WatchState()
        state.apply(update(.object(["n": .number(1), "m": .number(5)])), trackedPaths: tracked, now: t0)
        state.apply(update(.object(["n": .string("2")])), trackedPaths: tracked, now: t0 + 1)
        #expect(state.history(for: fp("n")).samples == [Sample(date: t0, value: 1), Sample(date: t0 + 1, value: 2)])
        #expect(state.history(for: fp("m")).samples.isEmpty)
        #expect(state.value == .object(["n": .string("2")]))
        #expect(state.status == .ok)
    }

    @Test func seedsWithoutDates() {
        var state = WatchState()
        state.apply(update(obj(3), seed: [obj(1), obj(2)]), trackedPaths: tracked, now: t0)
        #expect(state.history(for: fp("n")).samples == [
            Sample(date: nil, value: 1), Sample(date: nil, value: 2), Sample(date: t0, value: 3),
        ])
    }

    @Test func restartClearsHistory() {
        var state = WatchState()
        state.apply(update(obj(5)), trackedPaths: tracked, now: t0)
        state.apply(update(obj(1), restart: true), trackedPaths: tracked, now: t0 + 1)
        #expect(state.history(for: fp("n")).samples == [Sample(date: t0 + 1, value: 1)])
    }

    @Test func statusOnlyUpdatesKeepValue() {
        var state = WatchState()
        state.apply(update(obj(1), modified: t0), trackedPaths: tracked, now: t0)
        state.apply(WatchUpdate(status: .missing, snapshot: nil, modified: nil), trackedPaths: tracked, now: t0 + 1)
        #expect(state.value == obj(1))
        #expect(state.status == .missing)
        #expect(state.modified == t0)
    }

    @Test func statusLines() {
        var state = WatchState()
        #expect(state.statusLine(now: t0, staleAfter: 300) == "Waiting for file")
        state.apply(update(obj(1), modified: t0), trackedPaths: [], now: t0)
        #expect(state.statusLine(now: t0 + 3, staleAfter: 300) == "Updated 3s ago")
        #expect(state.statusLine(now: t0 + 420, staleAfter: 300) == "Stale — no updates for 7m")
        #expect(state.statusLine(now: t0 + 420, staleAfter: nil) == "Updated 7m ago")
        state.apply(WatchUpdate(status: .invalid("Invalid JSON: x"), snapshot: nil, modified: nil), trackedPaths: [], now: t0)
        #expect(state.statusLine(now: t0, staleAfter: 300) == "Invalid JSON: x")
        state.apply(WatchUpdate(status: .missing, snapshot: nil, modified: nil), trackedPaths: [], now: t0)
        #expect(state.statusLine(now: t0, staleAfter: 300) == "File not found")
    }

    @Test func attention() {
        var state = WatchState()
        #expect(!state.needsAttention(now: t0, staleAfter: 300))
        state.apply(update(obj(1), modified: t0), trackedPaths: [], now: t0)
        #expect(!state.needsAttention(now: t0 + 10, staleAfter: 300))
        #expect(state.needsAttention(now: t0 + 301, staleAfter: 300))
        #expect(state.isStale(now: t0 + 301, staleAfter: 300))
        state.apply(WatchUpdate(status: .missing, snapshot: nil, modified: nil), trackedPaths: [], now: t0)
        #expect(state.needsAttention(now: t0, staleAfter: 300))
        state.apply(WatchUpdate(status: .invalid("x"), snapshot: nil, modified: nil), trackedPaths: [], now: t0)
        #expect(state.needsAttention(now: t0, staleAfter: 300))
    }
}
