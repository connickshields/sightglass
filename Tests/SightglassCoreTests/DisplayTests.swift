import Foundation
import Testing
@testable import SightglassCore

struct DisplayTests {
    static let all: [Display] = [
        .text,
        .percent(source: .ratio(total: fp("progress.total"))),
        .bar(source: .fraction, showsPercent: true),
        .ring(source: .percentage, showsPercent: false),
        .sparkline(samples: 60),
        .rate(total: fp("total"), unit: "files"),
        .rate(total: nil, unit: nil),
        .badge(rules: BadgeRule.defaults),
    ]

    @Test(arguments: DisplayTests.all)
    func roundTripsThroughJSON(display: Display) throws {
        let data = try JSONEncoder().encode(display)
        #expect(try JSONDecoder().decode(Display.self, from: data) == display)
    }

    @Test func encodesPathsAsStrings() throws {
        let data = try JSONEncoder().encode(Display.percent(source: .ratio(total: fp("progress.total"))))
        #expect(String(decoding: data, as: UTF8.self).contains(#""total":"progress.total""#))
    }

    @Test func kinds() {
        #expect(Display.text.kind == .text)
        #expect(Display.bar(source: .fraction, showsPercent: true).kind == .bar)
        #expect(Display.badge(rules: []).kind == .badge)
        #expect(DisplayKind.allCases.count == 7)
    }

    @Test func progressSourceAccessor() {
        var bar = Display.bar(source: .fraction, showsPercent: false)
        bar.progressSource = .percentage
        #expect(bar == .bar(source: .percentage, showsPercent: false))
        var text = Display.text
        #expect(text.progressSource == nil)
        text.progressSource = .fraction
        #expect(text == .text)
    }

    @Test func otherAccessors() {
        var ring = Display.ring(source: .fraction, showsPercent: false)
        ring.showsPercent = true
        #expect(ring == .ring(source: .fraction, showsPercent: true))
        #expect(Display.percent(source: .fraction).showsPercent)

        var sparkline = Display.sparkline(samples: 60)
        sparkline.sparklineSamples = 120
        #expect(sparkline == .sparkline(samples: 120))

        var rate = Display.rate(total: nil, unit: nil)
        rate.rateTotal = fp("total")
        rate.rateUnit = "files"
        #expect(rate == .rate(total: fp("total"), unit: "files"))

        var badge = Display.badge(rules: [])
        badge.badgeRules = [BadgeRule(match: "x", symbol: "star", color: .yellow)]
        #expect(badge.badgeRules.count == 1)
    }
}

struct BadgeRuleTests {
    @Test func matchesCaseInsensitively() {
        #expect(BadgeRule.firstMatch(for: .string("Running"), in: BadgeRule.defaults)?.color == .blue)
        #expect(BadgeRule.firstMatch(for: .string(" DONE "), in: BadgeRule.defaults)?.symbol == "checkmark.circle.fill")
    }

    @Test func matchesBools() {
        #expect(BadgeRule.firstMatch(for: .bool(false), in: BadgeRule.defaults)?.color == .red)
        #expect(BadgeRule.firstMatch(for: .bool(true), in: BadgeRule.defaults)?.color == .green)
    }

    @Test func noMatchIsNil() {
        #expect(BadgeRule.firstMatch(for: .string("weird"), in: BadgeRule.defaults) == nil)
        #expect(BadgeRule.firstMatch(for: .number(1), in: BadgeRule.defaults) == nil)
    }

    @Test func firstRuleWins() {
        let rules = [BadgeRule(match: "ok", symbol: "a", color: .green), BadgeRule(match: "OK", symbol: "b", color: .red)]
        #expect(BadgeRule.firstMatch(for: .string("ok"), in: rules)?.symbol == "a")
    }
}

struct FieldConfigTests {
    @Test func titleFallsBackToPath() {
        #expect(FieldConfig(path: fp("a.b")).title == "a.b")
        #expect(FieldConfig(path: fp("a.b"), label: "").title == "a.b")
        #expect(FieldConfig(path: fp("a.b"), label: "DL").title == "DL")
    }
}
