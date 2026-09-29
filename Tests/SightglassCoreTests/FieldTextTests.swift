import Foundation
import Testing
@testable import SightglassCore

struct FieldTextTests {
    let en = Locale(identifier: "en_US")

    @Test func compactRate() {
        #expect(FieldText.compactRate(RateInfo(value: 0, perSecond: 3.44, total: 10, eta: 723), format: .auto, unit: nil, locale: en) == "3.4/s · 12m")
        #expect(FieldText.compactRate(RateInfo(value: 0, perSecond: nil, total: nil, eta: nil), format: .auto, unit: nil, locale: en) == "–/s")
        #expect(FieldText.compactRate(RateInfo(value: 0, perSecond: 3_400_000, total: nil, eta: nil), format: .bytes, unit: nil, locale: en) == "3.4 MB/s")
    }

    @Test func expandedRate() {
        let now = Date(timeIntervalSince1970: 0)
        #expect(FieldText.expandedRate(RateInfo(value: 0, perSecond: nil, total: nil, eta: nil), format: .auto, unit: nil, now: now, locale: en) == "No recent progress")
        let text = FieldText.expandedRate(RateInfo(value: 0, perSecond: 3.44, total: 10, eta: 723), format: .auto, unit: "files", now: now, locale: en)
        #expect(text.hasPrefix("3.4 files/s · 12m 03s left · finishes "))
    }

    @Test func progressDetail() {
        #expect(FieldText.progressDetail(ProgressInfo(value: 420, total: 1000, fraction: 0.42), format: .auto, locale: en) == "42% (420 / 1,000)")
        #expect(FieldText.progressDetail(ProgressInfo(value: 0.42, total: nil, fraction: 0.42), format: .auto, locale: en) == "42%")
    }

    @Test func sparklineDetail() {
        #expect(FieldText.sparklineDetail([3, 42, 40], format: .auto, locale: en) == "min 3 · max 42 · now 40")
        #expect(FieldText.sparklineDetail([], format: .auto, locale: en) == "")
    }

    @Test func measuringRate() {
        let info = RateInfo(value: 0, perSecond: nil, total: nil, eta: nil, isMeasuring: true)
        #expect(FieldText.compactRate(info, format: .auto, unit: nil, locale: en) == "Measuring…")
        #expect(FieldText.expandedRate(info, format: .auto, unit: nil, now: Date(timeIntervalSince1970: 0), locale: en) == "Measuring…")
    }
}
