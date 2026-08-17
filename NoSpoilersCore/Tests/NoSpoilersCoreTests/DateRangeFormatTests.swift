import XCTest
@testable import NoSpoilersCore

/// The weekend date span, which was three copies in three targets before it was
/// one function. These pin the two behaviours the copies shared — the arrow and
/// the same-day collapse — so a fourth copy cannot quietly reappear with a
/// different answer.
final class DateRangeFormatTests: XCTestCase {
    private let gb = Locale(identifier: "en_GB")
    private let london = TimeZone(identifier: "Europe/London")!

    func testSpanAcrossTwoDaysIsJoinedByAnArrow() {
        let output = Strings.Schedule.dateRange(
            from: makeUTCDate(year: 2026, month: 6, day: 12, hour: 12),
            to: makeUTCDate(year: 2026, month: 6, day: 14, hour: 15),
            locale: gb,
            timeZone: london
        )
        XCTAssertEqual(output, "12 Jun → 14 Jun")
    }

    /// iOS said "to" while macOS and the widget said "→". Unifying them changed
    /// iOS, so the separator is asserted rather than left to whichever copy was
    /// read last.
    func testTheSeparatorIsTheArrowAndNotTheWordTo() {
        let output = Strings.Schedule.dateRange(
            from: makeUTCDate(year: 2026, month: 6, day: 12, hour: 12),
            to: makeUTCDate(year: 2026, month: 6, day: 14, hour: 15),
            locale: gb,
            timeZone: london
        )
        XCTAssertFalse(output.contains(" to "), "expected no \"to\" separator in: \(output)")
    }

    func testASingleDayWeekendCollapsesToOneDate() {
        let output = Strings.Schedule.dateRange(
            from: makeUTCDate(year: 2026, month: 6, day: 12, hour: 9),
            to: makeUTCDate(year: 2026, month: 6, day: 12, hour: 18),
            locale: gb,
            timeZone: london
        )
        XCTAssertEqual(output, "12 Jun")
    }

    /// The collapse compares rendered text, not instants, so it has to follow the
    /// time zone the reader is in. 18:00 UTC on the 12th is still the 12th in
    /// London but already 04:00 on the 13th in Sydney, which turns one reader's
    /// same-day span into another's two-day one.
    func testTheCollapseFollowsTheReadersTimeZone() {
        let start = makeUTCDate(year: 2026, month: 6, day: 12, hour: 9)
        let end = makeUTCDate(year: 2026, month: 6, day: 12, hour: 18)

        XCTAssertEqual(
            Strings.Schedule.dateRange(from: start, to: end, locale: gb, timeZone: london),
            "12 Jun"
        )
        XCTAssertEqual(
            Strings.Schedule.dateRange(
                from: start,
                to: end,
                locale: gb,
                timeZone: TimeZone(identifier: "Australia/Sydney")!
            ),
            "12 Jun → 13 Jun"
        )
    }

    private func makeUTCDate(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }
}
