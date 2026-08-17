import XCTest
@testable import NoSpoilersCore

final class CountdownFormatterTests: XCTestCase {
    /// iOS: two units, stopping at minutes.
    private let iosApp = CountdownFormatter(units: 2, floor: .minutes)
    /// The macOS popover: three units, all the way to seconds.
    private let popover = CountdownFormatter(units: 3, floor: .seconds)

    // MARK: - Equivalence with what it replaced

    /// The iOS ladder exactly as it read before extraction, kept here so the
    /// claim "byte-identical" is checked rather than asserted. Delete it only
    /// when the two are deliberately meant to diverge.
    private func iosLadderAsItWas(_ r: DurationBreakdown) -> String {
        if r.days >= 1 { return "in \(r.days)d \(r.hours)h" }
        if r.hours >= 1 { return "in \(r.hours)h \(r.minutes)m" }
        return "in \(r.minutes)m"
    }

    /// The macOS popover ladder as it was.
    private func popoverLadderAsItWas(_ r: DurationBreakdown) -> String {
        if r.days >= 1 { return "\(r.days)d \(r.hours)h \(r.minutes)m" }
        if r.hours >= 1 { return "\(r.hours)h \(r.minutes)m \(r.seconds)s" }
        if r.minutes >= 1 { return "\(r.minutes)m \(r.seconds)s" }
        return "\(r.seconds)s"
    }

    /// Every tier boundary either ladder had, walked in one pass: just under a
    /// minute through four and a half days.
    func testItReproducesBothLaddersItReplaced() {
        for totalSeconds in stride(from: 1, through: 400_000, by: 37) {
            let remaining = DurationBreakdown(totalSeconds: totalSeconds)

            XCTAssertEqual(
                "in " + iosApp.string(for: remaining),
                iosLadderAsItWas(remaining),
                "iOS diverged at \(totalSeconds)s"
            )
            XCTAssertEqual(
                popover.string(for: remaining),
                popoverLadderAsItWas(remaining),
                "popover diverged at \(totalSeconds)s"
            )
        }
    }

    // MARK: - The rule itself

    func testCountingStartsAtTheLargestNonZeroUnit() {
        // 2h 15m 30s — no days, so the days slot is dropped rather than printed.
        let remaining = DurationBreakdown(totalSeconds: 2 * 3600 + 15 * 60 + 30)
        XCTAssertEqual(iosApp.string(for: remaining), "2h 15m")
        XCTAssertEqual(popover.string(for: remaining), "2h 15m 30s")
    }

    func testDaysPushTheFinerUnitsOffTheEnd() {
        // 3d 4h 5m 6s — iOS keeps two units, the popover three.
        let remaining = DurationBreakdown(totalSeconds: 3 * 86_400 + 4 * 3600 + 5 * 60 + 6)
        XCTAssertEqual(iosApp.string(for: remaining), "3d 4h")
        XCTAssertEqual(popover.string(for: remaining), "3d 4h 5m")
    }

    /// Under a minute, iOS has nothing left to show but its floor, and shows it
    /// as zero rather than an empty string. The popover, whose floor is seconds,
    /// still has a real number.
    func testUnderAMinuteEachSurfaceShowsItsFloor() {
        let remaining = DurationBreakdown(totalSeconds: 30)
        XCTAssertEqual(iosApp.string(for: remaining), "0m")
        XCTAssertEqual(popover.string(for: remaining), "30s")
    }

    /// A zero-length interval renders rather than crashing. Callers are expected
    /// to catch `isElapsed` first and say "now" or "0s" in their own words, but
    /// the formatter does not depend on their doing so.
    func testAnElapsedIntervalStillRenders() {
        let elapsed = DurationBreakdown(totalSeconds: 0)
        XCTAssertEqual(iosApp.string(for: elapsed), "0m")
        XCTAssertEqual(popover.string(for: elapsed), "0s")
    }

    /// An interval whose finer units are all zero keeps them, because dropping
    /// them would make "exactly two days" read as "2d" on a surface that has
    /// room for two units and shows "2d 3h" the rest of the time.
    func testZeroesAfterTheFirstSignificantUnitAreKept() {
        let remaining = DurationBreakdown(totalSeconds: 2 * 86_400)
        XCTAssertEqual(iosApp.string(for: remaining), "2d 0h")
        XCTAssertEqual(popover.string(for: remaining), "2d 0h 0m")
    }
}
