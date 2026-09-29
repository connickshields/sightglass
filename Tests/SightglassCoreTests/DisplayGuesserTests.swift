import Foundation
import Testing
@testable import SightglassCore

struct DisplayGuesserTests {
    let job = try! JSONValue.parse(Data(#"{"progress": {"downloaded": 420, "total": 1000, "percent": 42}, "done": 3}"#.utf8))

    @Test func badgeForKnownStatusWords() {
        #expect(DisplayGuesser.guess(path: fp("status"), value: .string("running")).display == .badge(rules: BadgeRule.defaults))
        #expect(DisplayGuesser.guess(path: fp("ok"), value: .bool(true)).display == .badge(rules: BadgeRule.defaults))
    }

    @Test func textForOtherStrings() {
        let guess = DisplayGuesser.guess(path: fp("current_file"), value: .string("a.zip"))
        #expect(guess.display == .text)
        #expect(guess.format == .auto)
    }

    @Test func percentForProgressKeys() {
        #expect(DisplayGuesser.guess(path: fp("job.progress"), value: .number(0.42)).display == .percent(source: .fraction))
        #expect(DisplayGuesser.guess(path: fp("percent_done"), value: .number(42)).display == .percent(source: .percentage))
    }

    @Test func bytesForSizeKeys() {
        #expect(DisplayGuesser.guess(path: fp("bytes_done"), value: .number(123)).format == .bytes)
        #expect(DisplayGuesser.guess(path: fp("file.Size"), value: .number(9)).format == .bytes)
    }

    @Test func textForOtherValues() {
        let count = DisplayGuesser.guess(path: fp("count"), value: .number(3))
        #expect(count.display == .text)
        #expect(count.format == .auto)
        #expect(DisplayGuesser.guess(path: fp("x"), value: .null).display == .text)
    }

    @Test func findsSiblingTotals() {
        #expect(DisplayGuesser.totalPath(for: fp("progress.downloaded"), in: job) == fp("progress.total"))
        #expect(DisplayGuesser.totalPath(for: fp("progress.total"), in: job) == nil)
        #expect(DisplayGuesser.totalPath(for: fp("done"), in: job) == nil)
        #expect(DisplayGuesser.totalPath(for: fp("done"), in: nil) == nil)
    }

    @Test func displayForKindPrefersRatioWithTotal() {
        #expect(DisplayGuesser.display(for: .bar, path: fp("progress.downloaded"), in: job)
            == .bar(source: .ratio(total: fp("progress.total")), showsPercent: true))
        #expect(DisplayGuesser.display(for: .rate, path: fp("progress.downloaded"), in: job)
            == .rate(total: fp("progress.total"), unit: nil))
    }

    @Test func displayForKindUsesPercentKeysDirectly() {
        #expect(DisplayGuesser.display(for: .ring, path: fp("progress.percent"), in: job)
            == .ring(source: .percentage, showsPercent: false))
    }

    @Test func displayForKindWithoutData() {
        #expect(DisplayGuesser.display(for: .percent, path: fp("x"), in: nil) == .percent(source: .fraction))
        #expect(DisplayGuesser.display(for: .sparkline, path: fp("x"), in: nil) == .sparkline(samples: 60))
        #expect(DisplayGuesser.display(for: .badge, path: fp("x"), in: nil) == .badge(rules: BadgeRule.defaults))
        #expect(DisplayGuesser.display(for: .text, path: fp("x"), in: nil) == .text)
    }
}
