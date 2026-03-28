import XCTest
@testable import NoSpoilersCore

final class RaceWeekendResolverTests: XCTestCase {
    func testFirstActiveWeekendReturnsEarliestWeekendWithUnfinishedSession() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let currentWeekend = makeWeekend(
            round: 1,
            name: "Australian",
            baseStart: now.addingTimeInterval(-3_600)
        )
        let futureWeekend = makeWeekend(
            round: 2,
            name: "Chinese",
            baseStart: now.addingTimeInterval(86_400)
        )

        let resolved = RaceWeekendResolver.firstActiveWeekend(in: [futureWeekend, currentWeekend], at: now)

        XCTAssertEqual(resolved?.round, 1)
    }

    func testCurrentWeekendRequiresStartedOrImminentWeekend() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let distantWeekend = makeWeekend(
            round: 3,
            name: "Japanese",
            baseStart: now.addingTimeInterval(10 * 86_400)
        )

        let resolved = RaceWeekendResolver.currentWeekend(in: [distantWeekend], at: now)

        XCTAssertNil(resolved)
    }

    func testFirstNonFinishedSessionSkipsFinishedSessions() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let finishedPractice = now.addingTimeInterval(-10_800)
        let upcomingQualifying = now.addingTimeInterval(3_600)
        let weekend = RaceWeekend(
            round: 4,
            name: "Miami",
            location: "Miami",
            sessions: [
                .freePractice1: finishedPractice,
                .qualifying: upcomingQualifying
            ]
        )

        let resolved = RaceWeekendResolver.firstNonFinishedSession(in: weekend, at: now)

        XCTAssertEqual(resolved?.kind, .qualifying)
    }

    private func makeWeekend(round: Int, name: String, baseStart: Date) -> RaceWeekend {
        RaceWeekend(
            round: round,
            name: name,
            location: name,
            sessions: [
                .freePractice1: baseStart,
                .qualifying: baseStart.addingTimeInterval(86_400),
                .race: baseStart.addingTimeInterval(2 * 86_400)
            ]
        )
    }
}
