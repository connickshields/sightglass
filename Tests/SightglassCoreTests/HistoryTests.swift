import Foundation
import Testing
@testable import SightglassCore

struct HistoryTests {
    @Test func recordsChangesOnly() {
        var history = History(capacity: 10)
        history.record(1, at: nil)
        history.record(1, at: nil)
        history.record(2, at: nil)
        #expect(history.samples.map(\.value) == [1, 2])
        #expect(history.latest == 2)
    }

    @Test func dropsOldestBeyondCapacity() {
        var history = History(capacity: 3)
        for value in 1...5 { history.record(Double(value), at: nil) }
        #expect(history.samples.map(\.value) == [3, 4, 5])
    }

    @Test func recentValues() {
        var history = History(capacity: 10)
        for value in 1...5 { history.record(Double(value), at: nil) }
        #expect(history.recentValues(2) == [4, 5])
        #expect(history.recentValues(0) == [])
        #expect(history.recentValues(99) == [1, 2, 3, 4, 5])
    }
}
