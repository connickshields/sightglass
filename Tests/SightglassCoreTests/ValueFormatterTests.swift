import Foundation
import Testing
@testable import SightglassCore

struct ValueFormatterTests {
    let en = Locale(identifier: "en_US")

    @Test func formatsNumbers() {
        #expect(ValueFormatter.string(for: 1000, format: .auto, locale: en) == "1,000")
        #expect(ValueFormatter.string(for: 3.14159, format: .auto, locale: en) == "3.14")
        #expect(ValueFormatter.string(for: 2.6, format: .integer, locale: en) == "3")
        #expect(ValueFormatter.string(for: 2, format: .decimal(places: 3), locale: en) == "2.000")
    }

    @Test func formatsBytes() {
        #expect(ValueFormatter.string(for: 1_200_000_000, format: .bytes, locale: en) == "1.2 GB")
        #expect(ValueFormatter.string(for: 512, format: .bytes, locale: en) == "512 bytes")
        #expect(ValueFormatter.string(for: 0, format: .bytes, locale: en) == "0 bytes")
        #expect(ValueFormatter.string(for: .infinity, format: .bytes, locale: en) == "0 bytes")
    }

    @Test func formatsDurations() {
        #expect(ValueFormatter.duration(45) == "45s")
        #expect(ValueFormatter.duration(723) == "12m 03s")
        #expect(ValueFormatter.duration(3720) == "1h 02m")
        #expect(ValueFormatter.duration(183_600) == "2d 03h")
        #expect(ValueFormatter.duration(-5) == "0s")
        #expect(ValueFormatter.duration(.nan) == "0s")
        #expect(ValueFormatter.string(for: 723, format: .duration, locale: en) == "12m 03s")
    }

    @Test func formatsShortDurations() {
        #expect(ValueFormatter.shortDuration(723) == "12m")
        #expect(ValueFormatter.shortDuration(45) == "45s")
        #expect(ValueFormatter.shortDuration(3720) == "1h 02m")
    }

    @Test func formatsRates() {
        #expect(ValueFormatter.rate(3.44, format: .auto, unit: nil, locale: en) == "3.4/s")
        #expect(ValueFormatter.rate(12, format: .auto, unit: "files", locale: en) == "12 files/s")
        #expect(ValueFormatter.rate(250.4, format: .auto, unit: nil, locale: en) == "250/s")
        #expect(ValueFormatter.rate(0.034, format: .auto, unit: nil, locale: en) == "0.034/s")
        #expect(ValueFormatter.rate(3_400_000, format: .bytes, unit: "files", locale: en) == "3.4 MB/s")
    }

    @Test func formatsJSONValues() {
        #expect(ValueFormatter.string(for: JSONValue.string("done"), format: .auto, locale: en) == "done")
        #expect(ValueFormatter.string(for: JSONValue.string("42"), format: .bytes, locale: en) == "42 bytes")
        #expect(ValueFormatter.string(for: JSONValue.bool(true), format: .integer, locale: en) == "true")
        #expect(ValueFormatter.string(for: JSONValue.number(1000), format: .integer, locale: en) == "1,000")
    }
}
