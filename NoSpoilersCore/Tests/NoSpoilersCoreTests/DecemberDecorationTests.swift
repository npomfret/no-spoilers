import XCTest
@testable import NoSpoilersCore

final class DecemberDecorationTests: XCTestCase {
    private let configuration = DecemberDecoration.Configuration()

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 1
    }

    func testSnowCrestsCannotCoverContentAboveTheReservedBottomSpace() {
        // Native rendering exposed the large widget's rear drift reaching above its reserve.
        // Check every painted layer, including the growing app drift at its maximum height.
        for canvas in Theme.Canvas.allCases {
            // WidgetKit supplies smaller margins on desktop/other hosts; do not assume 16pt.
            for margin in [CGFloat(0), 8, 11, 16] {
                let reserve = Theme.December.snowReserve(canvas, bottomMargin: margin)
                for elapsed in [0.0, 22, 120] {
                    let depth = NoSpoilersDecemberDecoration.driftDepth(canvas: canvas, elapsed: elapsed, bottomMargin: margin)
                    for width in [CGFloat(170), 300, 390, 620] {
                        for offset in [CGFloat(-4), 4, 19] {
                            let crest = stride(from: CGFloat(-2), through: width + 4, by: 1).map {
                                NoSpoilersDecemberDecoration.driftY(x: $0, size: CGSize(width: width, height: 400),
                                                                   depth: depth, offset: offset)
                            }.min()!
                            XCTAssertGreaterThanOrEqual(crest, 400 - reserve, "Snow must leave the content area clear")
                        }
                    }
                }
            }
        }
    }

    private func date(_ value: String) -> Date {
        guard let result = ISO8601DateFormatter().date(from: value) else {
            preconditionFailure("Test date must be ISO 8601")
        }
        return result
    }

    func testDefaultsIncludeDecemberFirstThroughTheEndOfDecemberTwentySixth() {
        let zone = TimeZone(secondsFromGMT: 0)!
        XCTAssertFalse(DecemberDecoration.isActive(at: date("2026-11-30T23:59:59Z"), timeZone: zone, configuration: configuration))
        XCTAssertTrue(DecemberDecoration.isActive(at: date("2026-12-01T00:00:00Z"), timeZone: zone, configuration: configuration))
        XCTAssertTrue(DecemberDecoration.isActive(at: date("2026-12-26T23:59:59Z"), timeZone: zone, configuration: configuration))
        XCTAssertFalse(DecemberDecoration.isActive(at: date("2026-12-27T00:00:00Z"), timeZone: zone, configuration: configuration))
        XCTAssertTrue(DecemberDecoration.isActive(at: date("2027-12-01T00:00:00Z"), timeZone: zone, configuration: configuration))
    }

    func testTemporaryPreviewConfigurationDoesNotChangeTheDefaultWindow() {
        let preview = DecemberDecoration.Configuration(startMonth: 11, startDay: 2)
        let zone = TimeZone(secondsFromGMT: 0)!
        let today = date("2026-11-02T00:00:00Z")
        XCTAssertFalse(DecemberDecoration.isActive(at: today.addingTimeInterval(-1), timeZone: zone, configuration: preview))
        XCTAssertTrue(DecemberDecoration.isActive(at: today, timeZone: zone, configuration: preview))
        XCTAssertFalse(DecemberDecoration.isActive(at: today, timeZone: zone, configuration: configuration))
        XCTAssertTrue(DecemberDecoration.isActive(at: date("2026-12-26T23:59:59Z"), timeZone: zone, configuration: preview))
        XCTAssertFalse(DecemberDecoration.isActive(at: date("2026-12-27T00:00:00Z"), timeZone: zone, configuration: preview))
    }

    func testWidgetPlansTheSuppliedStartAndInclusiveEndInsteadOfDefaultBoundaries() {
        let custom = DecemberDecoration.Configuration(startMonth: 11, startDay: 2, endMonth: 11, endDay: 2)
        let zone = TimeZone(secondsFromGMT: 0)!
        let now = date("2026-11-01T12:00:00Z")
        let plan = TimelinePlanner.plan(at: now, weekends: [], confirmedEndDates: [:],
                                        horizon: 48 * 3600, maxEntries: 24, timeZone: zone,
                                        decorationConfiguration: custom)
        XCTAssertEqual(plan.entryDates, [now, date("2026-11-02T00:00:00Z"), date("2026-11-03T00:00:00Z")])
        XCTAssertEqual(plan.entryDates.map { DecemberDecoration.isActive(at: $0, timeZone: zone, configuration: custom) }, [false, true, false])
    }

    func testTheSameMomentUsesTheSuppliedLocalTimeZone() {
        let moment = date("2026-12-01T02:00:00Z")
        XCTAssertTrue(DecemberDecoration.isActive(at: moment, timeZone: TimeZone(secondsFromGMT: 9 * 3600)!, configuration: configuration))
        XCTAssertFalse(DecemberDecoration.isActive(at: moment, timeZone: TimeZone(secondsFromGMT: -8 * 3600)!, configuration: configuration))
    }

    func testOffSeasonWidgetPlansTheLocalDecemberBoundary() {
        let now = date("2026-11-30T00:00:00Z")
        let zone = TimeZone(secondsFromGMT: 9 * 3600)!
        let plan = TimelinePlanner.plan(at: now, weekends: [], confirmedEndDates: [:],
                                        horizon: 48 * 3600, maxEntries: 24, timeZone: zone, decorationConfiguration: configuration)
        XCTAssertEqual(plan.entryDates, [now, date("2026-11-30T15:00:00Z")])
        XCTAssertEqual(plan.entryDates.map { DecemberDecoration.isActive(at: $0, timeZone: zone, configuration: configuration) }, [false, true])
        XCTAssertEqual(plan.reloadAt, now.addingTimeInterval(48 * 3600))
    }

    func testExhaustedSchedulePlansTheEndOfDecemberTwentySixthEvenWithoutASession() {
        let now = date("2026-12-26T00:00:00Z")
        let zone = TimeZone(secondsFromGMT: -8 * 3600)!
        let plan = TimelinePlanner.plan(at: now, weekends: [], confirmedEndDates: [:],
                                        horizon: 48 * 3600, maxEntries: 24, timeZone: zone, decorationConfiguration: configuration)
        XCTAssertEqual(plan.entryDates, [now, date("2026-12-27T08:00:00Z")])
        XCTAssertEqual(plan.entryDates.map { DecemberDecoration.isActive(at: $0, timeZone: zone, configuration: configuration) }, [true, false])
    }

    func testSeasonalBoundaryAtTheHorizonIsIncludedAndAtNowIsNotDuplicated() {
        let zone = TimeZone(secondsFromGMT: 0)!
        let start = date("2026-11-30T00:00:00Z")
        let december = date("2026-12-01T00:00:00Z")
        XCTAssertEqual(DecemberDecoration.boundaries(after: start, through: december, timeZone: zone, configuration: configuration), [december])
        let plan = TimelinePlanner.plan(at: december, weekends: [], confirmedEndDates: [:],
                                        horizon: 48 * 3600, maxEntries: 24, timeZone: zone, decorationConfiguration: configuration)
        XCTAssertEqual(plan.entryDates, [december])
    }

    func testSeasonAndSessionAtTheSameInstantShareAnEntryAndRespectTheCap() {
        let zone = TimeZone(secondsFromGMT: 0)!
        let now = date("2026-11-30T23:00:00Z")
        let december = date("2026-12-01T00:00:00Z")
        let weekend = RaceWeekend(round: 24, name: "Abu Dhabi", location: "Yas Marina", sessions: [.race: december])
        let full = TimelinePlanner.plan(at: now, weekends: [weekend], confirmedEndDates: [:],
                                        horizon: 48 * 3600, maxEntries: 24, timeZone: zone, decorationConfiguration: configuration)
        XCTAssertEqual(full.entryDates.filter { $0 == december }.count, 1)
        let capped = TimelinePlanner.plan(at: now, weekends: [weekend], confirmedEndDates: [:],
                                          horizon: 48 * 3600, maxEntries: 2, timeZone: zone, decorationConfiguration: configuration)
        XCTAssertEqual(capped.entryDates, [now, december])
        XCTAssertTrue(capped.truncated)
        XCTAssertEqual(capped.reloadAt, december)
    }
}
