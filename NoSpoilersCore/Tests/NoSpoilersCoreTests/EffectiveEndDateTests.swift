import XCTest
@testable import NoSpoilersCore

/// `Session.endsAt` is only `startsAt + kind.defaultDuration` — the scheduled end. The effective
/// end is what "finished N ago" should count from, and both apps used to count from the scheduled
/// one, which for a race is 90 minutes early.
final class EffectiveEndDateTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    func testFallsBackToTheGraceWindowWhenNothingIsConfirmed() {
        let race = Session(round: 1, grandPrixName: "Australian Grand Prix", location: "Melbourne", kind: .race, startsAt: start)

        let end = SessionResolver.effectiveEndDate(for: race, nextSession: nil, confirmedEndAt: nil)

        XCTAssertEqual(end, race.endsAt + SessionKind.race.gracePeriod)
        XCTAssertEqual(end.timeIntervalSince(race.endsAt), 90 * 60, "the gap the apps were reporting as elapsed time")
    }

    func testConfirmedEndReplacesTheGraceWindowEntirely() {
        let race = Session(round: 1, grandPrixName: "Australian Grand Prix", location: "Melbourne", kind: .race, startsAt: start)
        let confirmed = race.endsAt.addingTimeInterval(12 * 60)

        XCTAssertEqual(
            SessionResolver.effectiveEndDate(for: race, nextSession: nil, confirmedEndAt: confirmed),
            confirmed
        )
    }

    func testTheNextSessionStartingCapsTheEnd() {
        let practice = Session(round: 1, grandPrixName: "Australian Grand Prix", location: "Melbourne", kind: .freePractice1, startsAt: start)
        let next = Session(round: 1, grandPrixName: "Australian Grand Prix", location: "Melbourne", kind: .freePractice2, startsAt: practice.endsAt.addingTimeInterval(5 * 60))

        XCTAssertEqual(
            SessionResolver.effectiveEndDate(for: practice, nextSession: next, confirmedEndAt: nil),
            next.startsAt,
            "the grace window would otherwise run past the session that followed it"
        )
    }

    func testWeekendEndsWhenItsLastSessionDoes() {
        let weekend = RaceWeekend(
            round: 1,
            name: "Australian",
            location: "Melbourne",
            sessions: [.freePractice1: start, .qualifying: start.addingTimeInterval(86_400), .race: start.addingTimeInterval(2 * 86_400)]
        )
        let race = weekend.allSessions.last!

        XCTAssertEqual(
            RaceWeekendResolver.effectiveEndDate(of: weekend, confirmedEndDates: [:]),
            race.endsAt + SessionKind.race.gracePeriod
        )
    }

    func testWeekendEndUsesAConfirmedEndForItsLastSession() {
        let weekend = RaceWeekend(
            round: 1,
            name: "Australian",
            location: "Melbourne",
            sessions: [.qualifying: start, .race: start.addingTimeInterval(86_400)]
        )
        let race = weekend.allSessions.last!
        let confirmed = race.endsAt.addingTimeInterval(20 * 60)

        XCTAssertEqual(
            RaceWeekendResolver.effectiveEndDate(of: weekend, confirmedEndDates: [race.id: confirmed]),
            confirmed
        )
    }
}
