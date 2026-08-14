import XCTest
@testable import NoSpoilersCore

final class DurationBreakdownTests: XCTestCase {
    func testSplitsIntoTiers() {
        let d = DurationBreakdown(totalSeconds: 2 * 86_400 + 3 * 3_600 + 4 * 60 + 5)

        XCTAssertEqual(d.days, 2)
        XCTAssertEqual(d.hours, 3)
        XCTAssertEqual(d.minutes, 4)
        XCTAssertEqual(d.seconds, 5)
    }

    /// `hours` is within the day; `totalHours` is not capped. The "finished ago" labels use
    /// `totalHours`, which is what makes a session two days old read "48h" rather than "0h".
    func testTotalHoursIsNotCappedAtADay() {
        let d = DurationBreakdown(totalSeconds: 2 * 86_400)

        XCTAssertEqual(d.hours, 0)
        XCTAssertEqual(d.totalHours, 48)
    }

    func testElapsedIntervalsClampToZeroRatherThanGoingNegative() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let d = DurationBreakdown(until: now.addingTimeInterval(-3_600), from: now)

        XCTAssertEqual(d.totalSeconds, 0)
        XCTAssertTrue(d.isElapsed)
    }

    func testAnIntervalStillRunningIsNotElapsed() {
        let now = Date(timeIntervalSince1970: 1_000_000)

        XCTAssertFalse(DurationBreakdown(until: now.addingTimeInterval(1), from: now).isElapsed)
    }

    func testTimeSinceAPastDate() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let d = DurationBreakdown(since: now.addingTimeInterval(-(3_600 + 90)), to: now)

        XCTAssertEqual(d.totalHours, 1)
        XCTAssertEqual(d.minutes, 1)
    }
}
