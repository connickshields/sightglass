import Foundation
import Testing
@testable import SightglassCore

struct RateEstimatorTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    func samples(_ points: [(TimeInterval, Double)]) -> [Sample] {
        points.map { Sample(date: t0.addingTimeInterval($0.0), value: $0.1) }
    }

    @Test func steadyRate() throws {
        let points = (0..<10).map { (Double($0), Double($0) * 2) }
        let rate = try #require(RateEstimator.rate(from: samples(points), now: t0.addingTimeInterval(9)))
        #expect(abs(rate - 2) < 1e-9)
    }

    @Test func leastSquaresSlope() throws {
        let rate = try #require(RateEstimator.rate(from: samples([(0, 0), (1, 1), (2, 4)]), now: t0.addingTimeInterval(2)))
        #expect(abs(rate - 2) < 1e-9)
    }

    @Test func needsThreeTimedSamples() {
        #expect(RateEstimator.rate(from: samples([(0, 0), (1, 1)]), now: t0.addingTimeInterval(1)) == nil)
        let seeded = (0..<5).map { Sample(date: nil, value: Double($0)) } + samples([(0, 5), (1, 6)])
        #expect(RateEstimator.rate(from: seeded, now: t0.addingTimeInterval(1)) == nil)
    }

    @Test func nonPositiveRatesAreNil() {
        #expect(RateEstimator.rate(from: samples([(0, 5), (1, 4), (2, 3)]), now: t0.addingTimeInterval(2)) == nil)
        #expect(RateEstimator.rate(from: samples([(0, 5), (0, 6), (0, 7)]), now: t0) == nil)
    }

    @Test func stalledJobHasNoRate() {
        let points = samples([(0, 1), (1, 2), (2, 3)])
        #expect(RateEstimator.rate(from: points, now: t0.addingTimeInterval(92)) == nil)
    }

    @Test func slowJobFallsBackToLastSamples() throws {
        let points = samples([(0, 10), (40, 20), (80, 30)])
        let rate = try #require(RateEstimator.rate(from: points, now: t0.addingTimeInterval(100)))
        #expect(abs(rate - 0.25) < 1e-9)
    }

    @Test func onlyRecentSamplesCount() throws {
        let old = samples([(0, 0), (100, 10), (200, 20)])
        let recent = samples((0...6).map { (step: Int) -> (TimeInterval, Double) in
            let n = Double(step)
            return (300 + n * 10, 20 + n * 100)
        })
        let rate = try #require(RateEstimator.rate(from: old + recent, now: t0.addingTimeInterval(360)))
        #expect(abs(rate - 10) < 1e-9)
    }

    @Test func eta() {
        #expect(RateEstimator.eta(value: 400, total: 1000, rate: 2) == 300)
        #expect(RateEstimator.eta(value: 400, total: 1000, rate: 0) == nil)
        #expect(RateEstimator.eta(value: 1200, total: 1000, rate: 2) == 0)
    }
}
