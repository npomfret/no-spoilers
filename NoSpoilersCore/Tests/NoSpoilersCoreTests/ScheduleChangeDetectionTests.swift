import XCTest
@testable import NoSpoilersCore

/// `ScheduleStore.performRefresh` decides whether to reload widget timelines by comparing the
/// freshly fetched weekends against the ones it already has. It used to compare round numbers
/// only, which meant a rescheduled or cancelled session left the comparison unchanged and the
/// widget was never told. These cover the cases that comparison has to catch.
final class ScheduleChangeDetectionTests: XCTestCase {
    func testRescheduledSessionIsADifference() {
        let original = makeWeekend(round: 1, raceStart: Date(timeIntervalSince1970: 1_000_000))
        let moved = makeWeekend(round: 1, raceStart: Date(timeIntervalSince1970: 1_003_600))

        XCTAssertNotEqual([original], [moved])
    }

    func testCancelledSessionIsADifference() {
        let full = makeWeekend(round: 1, raceStart: Date(timeIntervalSince1970: 1_000_000))
        let withoutQualifying = RaceWeekend(
            round: 1,
            name: full.name,
            location: full.location,
            sessions: full.sessions.filter { $0.key != .qualifying }
        )

        XCTAssertNotEqual([full], [withoutQualifying])
    }

    func testIdenticalScheduleIsNotADifference() {
        let raceStart = Date(timeIntervalSince1970: 1_000_000)

        XCTAssertEqual([makeWeekend(round: 1, raceStart: raceStart)], [makeWeekend(round: 1, raceStart: raceStart)])
    }

    /// The old comparison. Kept as an explicit demonstration of what it missed, so nobody
    /// reintroduces it as a cheaper equivalent.
    func testRoundNumbersAloneCannotSeeAReschedule() {
        let original = makeWeekend(round: 1, raceStart: Date(timeIntervalSince1970: 1_000_000))
        let moved = makeWeekend(round: 1, raceStart: Date(timeIntervalSince1970: 1_003_600))

        XCTAssertEqual([original].map(\.round), [moved].map(\.round))
    }

    private func makeWeekend(round: Int, raceStart: Date) -> RaceWeekend {
        RaceWeekend(
            round: round,
            name: "Australian",
            location: "Melbourne",
            sessions: [
                .freePractice1: raceStart.addingTimeInterval(-2 * 86_400),
                .qualifying: raceStart.addingTimeInterval(-86_400),
                .race: raceStart
            ]
        )
    }
}
