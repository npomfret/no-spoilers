import XCTest
@testable import NoSpoilersCore

/// What should be on the Lock Screen, decided without a clock.
///
/// Tested for the same reason `SessionAlertPlannerTests` is: the mistakes are invisible. An
/// activity that never starts looks exactly like a weekend with nothing on, and once one *has*
/// started it lives on a Lock Screen the app cannot read back — so the decision to start it is the
/// only part of this feature anything can check.
final class FeaturedSessionPlannerTests: XCTestCase {

    private let now = Date(timeIntervalSinceReferenceDate: 0)
    private let eightHours: TimeInterval = 8 * 3600

    private func at(_ hours: Double) -> Date { now.addingTimeInterval(hours * 3600) }

    private func weekend(_ sessions: [SessionKind: Date], round: Int = 14) -> RaceWeekend {
        RaceWeekend(round: round, name: "Belgian", location: "Spa-Francorchamps", sessions: sessions)
    }

    private func plan(
        _ weekends: [RaceWeekend],
        confirmed: [String: Date] = [:],
        lookAhead: TimeInterval? = nil
    ) -> FeaturedSession? {
        FeaturedSessionPlanner.plan(
            at: now,
            weekends: weekends,
            confirmedEndDates: confirmed,
            lookAhead: lookAhead ?? eightHours
        )
    }

    // MARK: - Nothing to show

    func testAnEmptyScheduleShowsNothing() {
        XCTAssertNil(plan([]))
    }

    func testAWeekendEntirelyInThePastShowsNothing() {
        // A race at -12h ran 2h and carried a 90 minute grace, so it was over at -8.5h. The only
        // boundary left is the weekend ageing out of the recently-finished window, which says
        // nothing about any session.
        XCTAssertNil(plan([weekend([.race: at(-12)])]))
    }

    func testASessionBeyondTheLookAheadShowsNothing() {
        // Friday practice from a Tuesday. Real, and not worth a Lock Screen.
        XCTAssertNil(plan([weekend([.freePractice1: at(50)])]))
    }

    // MARK: - The next session

    func testTheNextSessionInsideTheLookAheadIsShownAsUpcoming() {
        let plan = plan([weekend([.race: at(4)])])

        XCTAssertEqual(plan?.session.kind, .race)
        XCTAssertEqual(plan?.phase, .upcoming)
        XCTAssertEqual(plan?.startsAt, at(4))
        // Two hours of race plus 90 minutes of grace.
        XCTAssertEqual(plan?.endsAt, at(7.5))
    }

    func testASessionStartingExactlyOnTheLookAheadIsStillShown() {
        // Inclusive, like the widget's horizon: excluding it would refuse an activity in the same
        // second the app decided to offer one.
        XCTAssertEqual(plan([weekend([.race: at(8)])], lookAhead: eightHours)?.phase, .upcoming)
    }

    func testTheSoonestSessionWinsAcrossWeekends() {
        let plan = plan([
            weekend([.race: at(30)], round: 15),
            weekend([.qualifying: at(3)], round: 14),
        ])

        XCTAssertEqual(plan?.session.round, 14)
        XCTAssertEqual(plan?.session.kind, .qualifying)
    }

    // MARK: - A session that is running

    func testASessionAlreadyRunningIsShownAsLiveAndBeatsTheNextOneToStart() {
        // Qualifying began half an hour ago and runs an hour; the race is tomorrow.
        let plan = plan([weekend([.qualifying: at(-0.5), .race: at(24)])])

        XCTAssertEqual(plan?.session.kind, .qualifying)
        XCTAssertEqual(plan?.phase, .live)
        XCTAssertEqual(plan?.startsAt, at(-0.5))
        // One hour of qualifying from -0.5h, plus 30 minutes of grace.
        XCTAssertEqual(plan?.endsAt, at(1))
    }

    func testASessionInsideItsGraceWindowIsStillLive() {
        // Started 70 minutes ago, scheduled to run an hour, 30 minutes of grace on top. The rest of
        // the product still calls this in progress, and the Lock Screen must not disagree with the
        // screen it is unlocked to.
        let plan = plan([weekend([.qualifying: at(-70.0 / 60.0)])])

        XCTAssertEqual(plan?.phase, .live)
        XCTAssertEqual(plan?.endsAt, at(20.0 / 60.0))
    }

    func testAConfirmedEndMovesTheLiveSessionsCountdownToWhenItActuallyFinished() {
        // The same correction `SessionAlertPlanner` gets from a confirmed end: without it the
        // countdown runs to a guess made from the grace window.
        let plan = plan([weekend([.race: at(-1)])], confirmed: ["14-gp": at(1.25)])

        XCTAssertEqual(plan?.phase, .live)
        XCTAssertEqual(plan?.endsAt, at(1.25))
    }

    func testAnUpcomingSessionsEndIsClampedByTheNextSessionStarting() {
        // Back-to-back sessions: sprint qualifying at +1h runs 45 minutes and carries 25 of grace,
        // which would put it over at +2h10 — after the sprint has already started at +2h.
        // `SessionResolver.effectiveEndDate` clamps it, and the activity must show the clamped
        // instant rather than recomputing a later one.
        let plan = plan([weekend([.sprintQualifying: at(1), .sprint: at(2)])])

        XCTAssertEqual(plan?.session.kind, .sprintQualifying)
        XCTAssertEqual(plan?.phase, .upcoming)
        XCTAssertEqual(plan?.endsAt, at(2))
    }
}
