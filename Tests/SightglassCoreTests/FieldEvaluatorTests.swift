import Foundation
import Testing
@testable import SightglassCore

struct FieldEvaluatorTests {
    let en = Locale(identifier: "en_US")
    let now = Date(timeIntervalSince1970: 1_000_000)
    let root = try! JSONValue.parse(Data(#"""
        {"status": "done", "name": "a.zip", "ok": true,
         "progress": {"downloaded": 420, "total": 1000, "zero": 0, "bytes": 1200000000,
                      "fraction": 0.42, "percent": 42, "text": "420", "over": 1100}}
        """#.utf8))

    func evaluate(_ path: String, _ display: Display, format: ValueFormat = .auto, history: History = History()) -> FieldState {
        FieldEvaluator.evaluate(FieldConfig(path: fp(path), display: display, format: format), in: root, history: history, now: now, locale: en)
    }

    @Test func noDataAndMissing() {
        #expect(FieldEvaluator.evaluate(FieldConfig(path: fp("a")), in: nil, history: History(), now: now) == .issue(.noData))
        #expect(evaluate("nope", .text) == .issue(.missing))
    }

    @Test func text() {
        #expect(evaluate("name", .text) == .text("a.zip"))
        #expect(evaluate("progress.bytes", .text, format: .bytes) == .text("1.2 GB"))
    }

    @Test func progressSources() {
        #expect(evaluate("progress.fraction", .percent(source: .fraction))
            == .progress(ProgressInfo(value: 0.42, total: nil, fraction: 0.42)))
        #expect(evaluate("progress.percent", .bar(source: .percentage, showsPercent: true))
            == .progress(ProgressInfo(value: 42, total: nil, fraction: 0.42)))
        #expect(evaluate("progress.downloaded", .ring(source: .ratio(total: fp("progress.total")), showsPercent: false))
            == .progress(ProgressInfo(value: 420, total: 1000, fraction: 0.42)))
    }

    @Test func ratioProblems() {
        #expect(evaluate("progress.downloaded", .percent(source: .ratio(total: fp("progress.zero")))) == .issue(.noTotal))
        #expect(evaluate("progress.downloaded", .percent(source: .ratio(total: fp("progress.nope")))) == .issue(.noTotal))
    }

    @Test func ratioAcceptsNumericStrings() {
        #expect(evaluate("progress.text", .percent(source: .ratio(total: fp("progress.total"))))
            == .progress(ProgressInfo(value: 420, total: 1000, fraction: 0.42)))
    }

    @Test func boolIsNotNumeric() {
        #expect(evaluate("ok", .percent(source: .fraction)) == .issue(.notNumeric))
        #expect(evaluate("name", .sparkline(samples: 10)) == .issue(.notNumeric))
        #expect(evaluate("name", .rate(total: nil, unit: nil)) == .issue(.notNumeric))
        #expect(FieldIssue.notNumeric.message == "Expected a number")
    }

    @Test func overCompletionKeepsTrueValue() {
        guard case .progress(let info) = evaluate("progress.over", .bar(source: .ratio(total: fp("progress.total")), showsPercent: true)) else {
            Issue.record("expected progress")
            return
        }
        #expect(info.clampedFraction == 1)
        #expect(info.percentText == "110%")
    }

    @Test func badges() {
        #expect(evaluate("status", .badge(rules: BadgeRule.defaults))
            == .badge(BadgeRule(match: "done", symbol: "checkmark.circle.fill", color: .green), raw: "done"))
        #expect(evaluate("name", .badge(rules: BadgeRule.defaults)) == .badge(.fallback, raw: "a.zip"))
    }

    @Test func sparklineUsesHistory() {
        var history = History()
        for value in [1.0, 5, 3] { history.record(value, at: nil) }
        #expect(evaluate("progress.downloaded", .sparkline(samples: 2), history: history) == .sparkline([5, 3]))
        #expect(evaluate("progress.downloaded", .sparkline(samples: 60)) == .sparkline([420]))
    }

    @Test func rateAndETA() {
        var history = History()
        for step in 0..<5 { history.record(Double(392 + step * 2), at: now.addingTimeInterval(Double(step - 4))) }
        guard case .rate(let info) = evaluate("progress.downloaded", .rate(total: fp("progress.total"), unit: nil), history: history) else {
            Issue.record("expected rate")
            return
        }
        #expect(info.value == 420)
        #expect(abs((info.perSecond ?? 0) - 2) < 1e-9)
        #expect(abs((info.eta ?? 0) - 290) < 1e-6)
    }

    @Test func rateWithoutTotalHasNoETA() {
        var history = History()
        for step in 0..<5 { history.record(Double(step), at: now.addingTimeInterval(Double(step - 4))) }
        guard case .rate(let info) = evaluate("progress.downloaded", .rate(total: nil, unit: nil), history: history) else {
            Issue.record("expected rate")
            return
        }
        #expect(info.perSecond != nil)
        #expect(info.eta == nil)
    }
}

struct StalenessTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test func staleAfterThreshold() {
        #expect(!Staleness.isStale(lastModified: t0, now: t0.addingTimeInterval(299), staleAfter: 300))
        #expect(Staleness.isStale(lastModified: t0, now: t0.addingTimeInterval(301), staleAfter: 300))
        #expect(!Staleness.isStale(lastModified: t0, now: t0.addingTimeInterval(9999), staleAfter: nil))
        #expect(!Staleness.isStale(lastModified: nil, now: t0, staleAfter: 300))
    }
}
