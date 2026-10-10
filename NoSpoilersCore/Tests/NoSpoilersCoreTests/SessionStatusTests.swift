import XCTest
@testable import NoSpoilersCore

final class SessionStatusTests: XCTestCase {
    private let start = ISO8601DateFormatter().date(from: "2026-10-10T09:00:00Z")!

    private var sprint: Session {
        Session(round: 17, grandPrixName: "Singapore Grand Prix", location: "Singapore",
                kind: .sprint, startsAt: start)
    }

    func testTheScheduledWindowDoesNotCertifyAFinish() {
        XCTAssertEqual(SessionResolver.status(for: sprint, at: start.addingTimeInterval(30 * 60),
                                             nextSession: nil, confirmedEndAt: nil), .inProgress)
        XCTAssertEqual(SessionResolver.status(for: sprint, at: start.addingTimeInterval(55 * 60),
                                             nextSession: nil, confirmedEndAt: nil), .unconfirmed)
    }

    func testTheNextScheduledStartIsNotProofThatTheSprintFinished() {
        let next = Session(round: 17, grandPrixName: "Singapore Grand Prix", location: "Singapore",
                           kind: .qualifying, startsAt: start.addingTimeInterval(4 * 3600))
        XCTAssertEqual(SessionResolver.status(for: sprint, at: next.startsAt,
                                             nextSession: next, confirmedEndAt: nil), .unconfirmed)
    }

    func testOnlyTheActualSingaporeFinishMakesTheSessionFinished() {
        let actualEnd = start.addingTimeInterval(76 * 60 + 19.195)
        XCTAssertEqual(SessionResolver.status(for: sprint, at: actualEnd,
                                             nextSession: nil, confirmedEndAt: actualEnd), .finished)
        XCTAssertEqual(SessionResolver.effectiveEndDate(for: sprint, nextSession: nil,
                                                       confirmedEndAt: actualEnd), actualEnd)
    }

    func testAnOlderStoredConfirmationCannotFinishThisSessionsOccurrence() {
        XCTAssertEqual(SessionResolver.status(for: sprint, at: start.addingTimeInterval(2 * 3600),
                                             nextSession: nil, confirmedEndAt: start.addingTimeInterval(-1)),
                       .unconfirmed)
    }

    func testTheCalendarBoundaryIsExplicitlyUnconfirmed() {
        let weekend = RaceWeekend(round: 17, name: "Singapore", location: "Singapore",
                                  sessions: [.sprint: start])
        let events = ScheduleBoundaries.all(after: start, weekends: [weekend], confirmedEndDates: [:])
        XCTAssertTrue(events.contains { $0.event == .sessionUnconfirmed(sprint) })
        XCTAssertFalse(events.contains { if case .sessionEnd = $0.event { return true }; return false })
    }

    func testAConfirmedFinalSessionAllowsTheWeekendToFinishWithoutInventingEarlierFinishes() {
        let weekend = RaceWeekend(round: 17, name: "Singapore", location: "Singapore",
                                  sessions: [.sprint: start, .race: start.addingTimeInterval(86_400)])
        let race = weekend.allSessions.last!
        let finish = race.endsAt
        let confirmations = [race.id: finish]
        XCTAssertNil(RaceWeekendResolver.firstNonFinishedSession(in: weekend, at: finish,
                                                                confirmedEndDates: confirmations))
        XCTAssertEqual(RaceWeekendResolver.effectiveEndDate(of: weekend, confirmedEndDates: confirmations), finish)
        XCTAssertEqual(SessionResolver.status(for: sprint, at: finish, nextSession: race,
                                             confirmedEndAt: nil), .unconfirmed)
    }

    func testArchivedUnconfirmedWeekendsDoNotBlockTheCurrentWeekend() {
        let old = RaceWeekend(round: 16, name: "Italian", location: "Monza",
                              sessions: [.race: start.addingTimeInterval(-7 * 86_400)])
        let current = RaceWeekend(round: 17, name: "Singapore", location: "Singapore",
                                  sessions: [.sprint: start])
        XCTAssertEqual(RaceWeekendResolver.firstActiveWeekend(in: [old, current], at: start,
                                                             confirmedEndDates: [:])?.round, 17)
        XCTAssertEqual(SessionResolver.status(for: old.allSessions[0], at: start, nextSession: nil,
                                             confirmedEndAt: nil), .unconfirmed)
    }
}
