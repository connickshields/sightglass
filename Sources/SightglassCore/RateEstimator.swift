import Foundation

public enum RateEstimator {
    public static let window: TimeInterval = 60
    public static let minSamples = 3

    /// Least-squares rate of change, in units per second.
    ///
    /// Uses timed samples from the last `window` seconds. When fewer than
    /// `minSamples` fall inside it (a slow-updating job), it uses the last
    /// `minSamples` timed samples instead, as long as the newest is no older
    /// than `max(window, 2 × their average spacing)`, so a stalled job gets nil.
    /// Returns nil without enough data or when the rate isn't positive.
    public static func rate(from samples: [Sample], now: Date, window: TimeInterval = window, minSamples: Int = minSamples) -> Double? {
        let timed = samples.compactMap { sample in sample.date.map { (time: $0, value: sample.value) } }
        var points = timed.filter { now.timeIntervalSince($0.time) <= window }
        if points.count < minSamples {
            points = Array(timed.suffix(minSamples))
            guard points.count >= minSamples, let first = points.first, let last = points.last else { return nil }
            let spacing = last.time.timeIntervalSince(first.time) / Double(points.count - 1)
            guard now.timeIntervalSince(last.time) <= max(window, 2 * spacing) else { return nil }
        }
        guard let origin = points.first?.time else { return nil }

        let xs = points.map { $0.time.timeIntervalSince(origin) }
        let ys = points.map(\.value)
        let count = Double(points.count)
        let meanX = xs.reduce(0, +) / count
        let meanY = ys.reduce(0, +) / count
        var covariance = 0.0
        var variance = 0.0
        for (x, y) in zip(xs, ys) {
            covariance += (x - meanX) * (y - meanY)
            variance += (x - meanX) * (x - meanX)
        }
        guard variance > 0 else { return nil }
        let slope = covariance / variance
        return slope > 0 ? slope : nil
    }

    /// Seconds until `value` reaches `total` at `rate`; nil unless `rate > 0`.
    public static func eta(value: Double, total: Double, rate: Double) -> TimeInterval? {
        guard rate > 0 else { return nil }
        return max(0, (total - value) / rate)
    }
}
