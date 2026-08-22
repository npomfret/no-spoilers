import XCTest
@testable import NoSpoilersCore

/// What the app will have pending with the OS, decided without a clock.
///
/// These matter more than their size suggests: a notification that never arrives is indispensable
/// from a weekend where nothing happened, so nothing about this is observable in use. It is the
/// same invisibility that made `TimelinePlannerTests` worth building, and it is tested the same way.
final class SessionAlertPlannerTests: XCTestCase {

    private let now = Date(timeIntervalSinceReferenceDate: 0)
    private let halfAnHour: TimeInterval = 30 * 60

    private func at(_ hours: Double) -> Date { now.addingTimeInterval(hours * 3600) }

    private func weekend(_ sessions: [SessionKind: Date], round: Int = 14) -> RaceWeekend {
        RaceWeekend(round: round, name: "Belgian", location: "Spa-Francorchamps", sessions: sessions)
    }

    private func preferences(
        startLead: TimeInterval? = 30 * 60,
        announceSafeToWatch: Bool = true,
        kinds: Set<SessionKind> = Set(SessionKind.allCases)
    ) -> SessionAlertPreferences {
        SessionAlertPreferences(
            startLead: startLead,
            announceSafeToWatch: announceSafeToWatch,
            kinds: kinds
        )
    }

    private func plan(
        _ weekends: [RaceWeekend],
        confirmed: [String: Date] = [:],
        preferences prefs: SessionAlertPreferences? = nil,
        limit: Int = 64
    ) -> [SessionAlert] {
        SessionAlertPlanner.plan(
            at: now,
            weekends: weekends,
            confirmedEndDates: confirmed,
            preferences: prefs ?? preferences(),
            limit: limit
        )
    }

    // MARK: - What gets planned

    func testARaceGetsAWarningBeforeItAndAnAllClearAfterIt() {
        // A race at +4h runs 2h and carries a 90 minute grace period, so it is effectively over
        // at +7.5h. The warning lands half an hour before the start.
        let alerts = plan([weekend([.race: at(4)])])

        XCTAssertEqual(alerts.map(\.fireAt), [at(3.5), at(7.5)])
        XCTAssertEqual(alerts.map(\.kind), [.startingSoon(lead: halfAnHour), .safeToWatch])
        XCTAssertEqual(alerts.map(\.id), ["14-gp-start", "14-gp-safe"])
    }

    func testAConfirmedEndMovesTheAllClearToWhenTheSessionActuallyFinished() {
        // The whole point of the OpenF1 poll: without it the all-clear is an estimate from the
        // grace window, and a race that overran would be called safe while it was still running.
        let race = weekend([.race: at(4)])
        let sessionID = race.allSessions[0].id
        let alerts = plan([race], confirmed: [sessionID: at(9)])

        XCTAssertEqual(alerts.map(\.fireAt), [at(3.5), at(9)])
    }

    // MARK: - What the preferences turn off

    func testTurningOffTheStartWarningLeavesOnlyTheAllClear() {
        let alerts = plan([weekend([.race: at(4)])], preferences: preferences(startLead: nil))

        XCTAssertEqual(alerts.map(\.kind), [.safeToWatch])
    }

    func testTurningOffTheAllClearLeavesOnlyTheStartWarning() {
        let alerts = plan(
            [weekend([.race: at(4)])],
            preferences: preferences(announceSafeToWatch: false)
        )

        XCTAssertEqual(alerts.map(\.kind), [.startingSoon(lead: halfAnHour)])
    }

    func testASessionKindNotAskedForIsSilentInBothDirections() {
        // Three hours of practice a weekend is the reason this preference exists.
        let alerts = plan(
            [weekend([.freePractice1: at(1), .race: at(4)])],
            preferences: preferences(kinds: [.race])
        )

        XCTAssertEqual(alerts.map(\.session.kind), [.race, .race])
    }

    // MARK: - The edges

    func testASessionStartingInsideTheLeadTimeGetsNoWarningAtAll() {
        // Ten minutes away, with a thirty minute lead. Firing now would deliver "starts in 30
        // minutes" ten minutes beforehand, which is worse than saying nothing.
        let alerts = plan([weekend([.race: at(1.0 / 6.0)])])

        XCTAssertEqual(alerts.map(\.kind), [.safeToWatch], "the all-clear is still ahead of us")
    }

    func testASessionAlreadyOverIsNotAnnouncedLate() {
        // Started 6 hours ago and effectively over 2.5 hours ago. Nothing here is in the future.
        let alerts = plan([weekend([.race: at(-6)])])

        XCTAssertEqual(alerts, [])
    }

    func testTheLimitKeepsTheSoonestAlertsAndDropsTheRest() {
        // iOS keeps 64 pending and silently drops the rest, so the ones kept have to be the near
        // ones. Four sessions produce eight alerts; the cap takes the first three by fire time.
        let alerts = plan(
            [weekend([.freePractice1: at(1), .freePractice2: at(5), .qualifying: at(9), .race: at(13)])],
            limit: 3
        )

        XCTAssertEqual(alerts.map(\.fireAt), [at(0.5), at(2.5), at(4.5)])
    }

    func testAWarningPushedBackByItsLeadIsStillPlacedInFireOrder() {
        // FP2 ends effectively at +6.5h (1h + 30min grace) and the race warning fires at +6h, so
        // the warning overtakes the earlier session's all-clear. Boundary order is not fire order.
        let alerts = plan([weekend([.freePractice2: at(5), .race: at(6.5)])])

        XCTAssertEqual(alerts.map(\.fireAt), alerts.map(\.fireAt).sorted())
        XCTAssertEqual(alerts.map(\.id).first, "14-fp2-start")
    }

    func testAnEmptyScheduleAsksForNothing() {
        XCTAssertEqual(plan([]), [])
    }
}
