import XCTest
@testable import NoSpoilersCore

final class SessionDateTimeFormatTests: XCTestCase {
    /// 2026-06-12 19:00 UTC — chosen so BST (UTC+1) and EDT (UTC-4) both fall on
    /// June 12 with whole-hour offsets that are easy to assert.
    private let date = makeUTCDate(year: 2026, month: 6, day: 12, hour: 19, minute: 0)

    func testRendersInLondonTimeZoneAndGBLocale() {
        let output = Strings.Schedule.sessionDateTime(
            date,
            locale: Locale(identifier: "en_GB"),
            timeZone: TimeZone(identifier: "Europe/London")!
        )
        XCTAssertTrue(output.contains("20:00"), "expected London time 20:00 in: \(output)")
        XCTAssertTrue(output.contains("12"), "expected day 12 in: \(output)")
        XCTAssertTrue(output.contains("Jun"), "expected Jun in: \(output)")
        XCTAssertTrue(output.contains("Fri"), "expected Fri in: \(output)")
    }

    func testRendersInNewYorkTimeZoneAndUSLocale() {
        let output = Strings.Schedule.sessionDateTime(
            date,
            locale: Locale(identifier: "en_US"),
            timeZone: TimeZone(identifier: "America/New_York")!
        )
        XCTAssertTrue(output.contains("3:00"), "expected New York 3:00 PM in: \(output)")
        XCTAssertTrue(output.contains("PM"), "expected PM marker in: \(output)")
        XCTAssertTrue(output.contains("Jun"), "expected Jun in: \(output)")
        XCTAssertTrue(output.contains("12"), "expected day 12 in: \(output)")
    }

    func testTimeZoneShiftCanCrossADayBoundary() {
        // 23:30 UTC on the 12th is 09:30 on the 13th in Sydney (AEST UTC+10).
        let lateNight = SessionDateTimeFormatTests.makeUTCDate(year: 2026, month: 6, day: 12, hour: 23, minute: 30)
        let output = Strings.Schedule.sessionDateTime(
            lateNight,
            locale: Locale(identifier: "en_GB"),
            timeZone: TimeZone(identifier: "Australia/Sydney")!
        )
        XCTAssertTrue(output.contains("13"), "expected rolled-over day 13 in: \(output)")
        XCTAssertTrue(output.contains("Sat"), "expected Saturday in: \(output)")
        XCTAssertTrue(output.contains("09:30") || output.contains("9:30"), "expected 09:30 in: \(output)")
    }

    private static func makeUTCDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
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
