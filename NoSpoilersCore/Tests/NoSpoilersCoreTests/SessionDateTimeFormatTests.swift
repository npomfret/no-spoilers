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

    func testFullPresentationUsesFullMonthAndLocalTwentyFourHourTime() {
        let output = Strings.Schedule.sessionDateTime(
            date,
            locale: Locale(identifier: "en_GB"),
            timeZone: TimeZone(identifier: "Europe/London")!,
            style: .full
        )
        XCTAssertTrue(output.contains("June"), "expected full month in: \(output)")
        XCTAssertTrue(output.contains("12"), "expected day 12 in: \(output)")
        XCTAssertTrue(output.contains("20:00"), "expected London time in: \(output)")
    }

    func testFullPresentationHonoursTwelveHourLocales() {
        let output = Strings.Schedule.sessionDateTime(
            date,
            locale: Locale(identifier: "en_US"),
            timeZone: TimeZone(identifier: "America/New_York")!,
            style: .full
        )
        XCTAssertTrue(output.contains("June"), "expected full month in: \(output)")
        XCTAssertTrue(output.contains("3:00"), "expected New York time in: \(output)")
        XCTAssertTrue(output.contains("PM"), "expected locale's PM marker in: \(output)")
    }

    func testFullPresentationKeepsNonHourOffsetsAndLocalDateRollover() {
        let start = Self.makeUTCDate(year: 2026, month: 9, day: 12, hour: 22, minute: 15)
        let output = Strings.Schedule.sessionDateTime(
            start,
            locale: Locale(identifier: "en_GB"),
            timeZone: TimeZone(identifier: "Asia/Kathmandu")!,
            style: .full
        )
        XCTAssertTrue(output.contains("13"), "expected local day 13 in: \(output)")
        XCTAssertTrue(output.contains("September"), "expected full month in: \(output)")
        XCTAssertTrue(output.contains("04:00") || output.contains("4:00"), "expected UTC+5:45 in: \(output)")
    }

    func testWidgetPresentationUsesTheLocalDayAndWeekday() {
        let lateNight = Self.makeUTCDate(year: 2026, month: 6, day: 12, hour: 23, minute: 30)
        let output = Strings.Schedule.sessionDateTime(
            lateNight,
            locale: Locale(identifier: "en_GB"),
            timeZone: TimeZone(identifier: "Europe/London")!,
            style: .widget
        )
        XCTAssertTrue(output.contains("13"), "expected local day 13 in: \(output)")
        XCTAssertTrue(output.contains("Sat"), "expected local Saturday in: \(output)")
        XCTAssertTrue(output.contains("13th"), "expected local ordinal day 13th in: \(output)")
        XCTAssertFalse(output.contains("Jun"), "month must not crowd the widget: \(output)")
    }

    func testWidgetPresentationIncludesEnglishOrdinalSuffixes() {
        for (day, expected) in [(1, "1st"), (2, "2nd"), (3, "3rd"), (11, "11th"), (12, "12th"), (13, "13th"), (21, "21st"), (22, "22nd"), (23, "23rd"), (27, "27th"), (31, "31st")] {
            let output = Strings.Schedule.sessionDateTime(
                Self.makeUTCDate(year: 2026, month: 7, day: day, hour: 12, minute: 0),
                locale: Locale(identifier: "en_GB"),
                timeZone: TimeZone(identifier: "UTC")!,
                style: .widget
            )
            XCTAssertTrue(output.contains(expected), "expected \(expected) in: \(output)")
        }
    }

    func testWidgetPresentationMatchesRequestedFridayDate() {
        XCTAssertEqual(
            Strings.Schedule.sessionDateTime(
                Self.makeUTCDate(year: 2026, month: 11, day: 27, hour: 12, minute: 0),
                locale: Locale(identifier: "en_GB"),
                timeZone: TimeZone(identifier: "UTC")!,
                style: .widget
            ),
            "Fri 27th"
        )
    }

    func testRoomyWidgetIncludesLocalOrdinalDateAndClockTime() {
        let start = Self.makeUTCDate(year: 2026, month: 11, day: 27, hour: 14, minute: 30)
        let output = Strings.Schedule.sessionDateTime(
            start,
            locale: Locale(identifier: "en_GB"),
            timeZone: TimeZone(identifier: "Europe/London")!,
            style: .widgetWithTime
        )
        XCTAssertTrue(output.contains("Fri"), output)
        XCTAssertTrue(output.contains("27th"), output)
        XCTAssertTrue(output.contains("14:30"), output)
    }

    func testRoomyWidgetHonoursTwelveHourLocale() {
        let output = Strings.Schedule.sessionDateTime(
            date,
            locale: Locale(identifier: "en_US"),
            timeZone: TimeZone(identifier: "America/New_York")!,
            style: .widgetWithTime
        )
        XCTAssertTrue(output.contains("12th"), output)
        XCTAssertTrue(output.contains("3:00"), output)
        XCTAssertTrue(output.contains("PM"), output)
    }

    func testRoomyWidgetKeepsDateAndTimeOnTheSameLocalDay() {
        let start = Self.makeUTCDate(year: 2026, month: 6, day: 12, hour: 23, minute: 30)
        let output = Strings.Schedule.sessionDateTime(
            start,
            locale: Locale(identifier: "en_GB"),
            timeZone: TimeZone(identifier: "Europe/London")!,
            style: .widgetWithTime
        )
        XCTAssertTrue(output.contains("Sat"), output)
        XCTAssertTrue(output.contains("13th"), output)
        XCTAssertTrue(output.contains("00:30"), output)
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
