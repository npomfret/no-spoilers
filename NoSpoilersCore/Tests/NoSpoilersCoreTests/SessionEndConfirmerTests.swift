import XCTest
@testable import NoSpoilersCore

final class SessionEndConfirmerTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_791_622_800)

    private func sprint() -> Session {
        Session(round: 17, grandPrixName: "Singapore Grand Prix", location: "Singapore",
                kind: .sprint, startsAt: start)
    }

    func testTheDelayedSprintStillNeedsConfirmationPastItsGraceEstimate() {
        let session = sprint()
        let now = start.addingTimeInterval(4 * 3600)
        XCTAssertEqual(SessionEndConfirmer.pendingSessions(in: [session], at: now,
                                                          confirmedEndDates: [:]), [session])
    }

    func testTheNextSessionDoesNotStopConfirmationWhileFreeAccessIsBlocked() {
        let session = sprint()
        let qualifying = Session(round: 17, grandPrixName: "Singapore Grand Prix", location: "Singapore",
                                 kind: .qualifying, startsAt: start.addingTimeInterval(4 * 3600))
        XCTAssertEqual(SessionEndConfirmer.pendingSessions(
            in: [session, qualifying], at: qualifying.startsAt, confirmedEndDates: [:]), [session])
    }

    func testAConfirmedSessionStopsPolling() {
        let session = sprint()
        XCTAssertEqual(SessionEndConfirmer.pendingSessions(
            in: [session], at: start.addingTimeInterval(4 * 3600),
            confirmedEndDates: [session.id: start.addingTimeInterval(3 * 3600)]), [])
    }

    func testARefreshBeforeTheSprintArmsItsScheduledEnd() {
        let session = sprint()
        XCTAssertEqual(SessionEndConfirmer.nextScheduledEnd(in: [session], after: start), session.endsAt)
        XCTAssertNil(SessionEndConfirmer.nextScheduledEnd(in: [session], after: session.endsAt))
    }

    func testPollingDoesNotStartBeforeTheScheduledEndOrScanTheWholeSeason() {
        let session = sprint()
        XCTAssertEqual(SessionEndConfirmer.pendingSessions(in: [session], at: start,
                                                          confirmedEndDates: [:]), [])
        XCTAssertEqual(SessionEndConfirmer.pendingSessions(
            in: [session], at: session.endsAt.addingTimeInterval(24 * 3600), confirmedEndDates: [:]), [])
    }
}
