import Foundation

/// A numeric observation. `date` is nil for values seeded from old NDJSON lines.
public struct Sample: Equatable, Sendable {
    public var date: Date?
    public var value: Double

    public init(date: Date?, value: Double) {
        self.date = date
        self.value = value
    }
}

/// A fixed-capacity, oldest-first list of samples.
public struct History: Equatable, Sendable {
    public let capacity: Int
    public private(set) var samples: [Sample] = []

    public init(capacity: Int = 300) {
        self.capacity = max(1, capacity)
    }

    public var latest: Double? { samples.last?.value }

    /// Appends a sample unless it repeats the latest value.
    public mutating func record(_ value: Double, at date: Date?) {
        guard value != samples.last?.value else { return }
        samples.append(Sample(date: date, value: value))
        if samples.count > capacity {
            samples.removeFirst(samples.count - capacity)
        }
    }

    /// The most recent `count` values, oldest first.
    public func recentValues(_ count: Int) -> [Double] {
        samples.suffix(max(0, count)).map(\.value)
    }
}
