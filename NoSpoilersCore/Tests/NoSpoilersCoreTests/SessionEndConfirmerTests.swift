import XCTest
@testable import NoSpoilersCore

final class SessionEndConfirmerTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_791_622_800)

    private func sprint() -> Session {
        Session(round: 17, grandPrixName: "Singapore Grand Prix", location: "Singapore",
                kind: .sprint, startsAt: start)
    }

    private func weekend(_ sessions: [Session]) -> RaceWeekend {
        RaceWeekend(round: 17, name: "Singapore", location: "Singapore",
                    sessions: Dictionary(uniqueKeysWithValues: sessions.map { ($0.kind, $0.startsAt) }))
    }

    func testTheDelayedSprintStillNeedsConfirmationPastItsGraceEstimate() {
        let session = sprint()
        let now = start.addingTimeInterval(4 * 3600)
        XCTAssertEqual(SessionEndConfirmer.pendingSessions(in: [weekend([session])], at: now,
                                                          confirmedEndDates: [:]), [session])
    }

    func testTheNextSessionDoesNotStopConfirmationWhileFreeAccessIsBlocked() {
        let session = sprint()
        let qualifying = Session(round: 17, grandPrixName: "Singapore Grand Prix", location: "Singapore",
                                 kind: .qualifying, startsAt: start.addingTimeInterval(4 * 3600))
        XCTAssertEqual(SessionEndConfirmer.pendingSessions(
            in: [weekend([session, qualifying])], at: qualifying.startsAt, confirmedEndDates: [:]), [session])
    }

    func testAConfirmedSessionStopsPolling() {
        let session = sprint()
        XCTAssertEqual(SessionEndConfirmer.pendingSessions(
            in: [weekend([session])], at: start.addingTimeInterval(4 * 3600),
            confirmedEndDates: [session.id: start.addingTimeInterval(3 * 3600)]), [])
    }

    func testARefreshBeforeTheSprintArmsItsScheduledEnd() {
        let session = sprint()
        XCTAssertEqual(SessionEndConfirmer.nextScheduledEnd(in: [session], after: start), session.endsAt)
        XCTAssertNil(SessionEndConfirmer.nextScheduledEnd(in: [session], after: session.endsAt))
    }

    func testPollingDoesNotStartBeforeTheScheduledEnd() {
        let session = sprint()
        XCTAssertEqual(SessionEndConfirmer.pendingSessions(in: [weekend([session])], at: start,
                                                          confirmedEndDates: [:]), [])
    }

    func testAnUnconfirmedSessionIsRetriedPastADayWhileItsWeekendIsShown() {
        // Singapore 2026: FP1 passed 24 hours unconfirmed on Saturday and stayed
        // "Finish not confirmed" with the finish published.
        let practice = Session(round: 17, grandPrixName: "Singapore Grand Prix", location: "Singapore",
                               kind: .freePractice1, startsAt: start)
        let race = Session(round: 17, grandPrixName: "Singapore Grand Prix", location: "Singapore",
                           kind: .race, startsAt: start.addingTimeInterval(52 * 3600))
        XCTAssertEqual(SessionEndConfirmer.pendingSessions(
            in: [weekend([practice, race])], at: start.addingTimeInterval(32 * 3600),
            confirmedEndDates: [:]), [practice])
    }

    func testAnArchivedWeekendIsNotPolled() {
        let session = sprint()
        let archived = RaceWeekendResolver.archiveDate(of: weekend([session]), confirmedEndDates: [:])
        XCTAssertEqual(SessionEndConfirmer.pendingSessions(
            in: [weekend([session])], at: archived, confirmedEndDates: [:]), [])
    }
}
