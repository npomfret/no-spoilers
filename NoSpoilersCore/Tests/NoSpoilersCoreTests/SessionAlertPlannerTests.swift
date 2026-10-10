import XCTest
import UserNotifications
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
        announced: [String: Date] = [:],
        preferences prefs: SessionAlertPreferences? = nil,
        limit: Int = 64
    ) -> [SessionAlert] {
        SessionAlertPlanner.plan(
            at: now,
            weekends: weekends,
            confirmedEndDates: confirmed,
            announcedEndDates: announced,
            preferences: prefs ?? preferences(),
            limit: limit
        )
    }

    // MARK: - What gets planned

    func testAnUnconfirmedRaceGetsOnlyItsStartWarning() {
        let alerts = plan([weekend([.race: at(4)])])

        XCTAssertEqual(alerts.map(\.fireAt), [at(3.5)])
        XCTAssertEqual(alerts.map(\.kind), [.startingSoon(lead: halfAnHour)])
        XCTAssertEqual(alerts.map(\.id), ["14-gp-start"])
    }

    func testAConfirmedPastEndAnnouncesTheFinishNow() {
        let race = weekend([.race: at(-4)])
        let sessionID = race.allSessions[0].id
        let alerts = plan([race], confirmed: [sessionID: at(-0.5)])

        XCTAssertEqual(alerts.map(\.fireAt), [now])
        XCTAssertEqual(alerts.map(\.kind), [.safeToWatch])
    }

    func testTheSingaporeSprintEstimateNeverSchedulesAnAllClear() {
        let startsAt = ISO8601DateFormatter().date(from: "2026-10-10T09:00:00Z")!
        let singapore = RaceWeekend(round: 17, name: "Singapore", location: "Singapore",
                                    sessions: [.sprint: startsAt])
        for minutes in [-60, 55, 56, 272] {
            let alerts = SessionAlertPlanner.plan(
                at: startsAt.addingTimeInterval(TimeInterval(minutes * 60)),
                weekends: [singapore], confirmedEndDates: [:], announcedEndDates: [:],
                preferences: preferences(), limit: 64
            )
            XCTAssertFalse(alerts.contains { $0.kind == .safeToWatch })
        }
        // OpenF1's actual finish was 10:16:19.195Z, 21 minutes after the estimated all-clear.
        // Once historical access returns, the notification must be due now despite that past end.
        let actualEnd = startsAt.addingTimeInterval(76 * 60 + 19.195)
        let receivedAt = actualEnd.addingTimeInterval(30 * 60)
        let confirmed = SessionAlertPlanner.plan(
            at: receivedAt, weekends: [singapore], confirmedEndDates: ["17-sprint": actualEnd],
            announcedEndDates: [:], preferences: preferences(), limit: 64
        )
        XCTAssertEqual(confirmed.map(\.kind), [.safeToWatch])
        XCTAssertEqual(confirmed.map(\.fireAt), [receivedAt])
    }

    func testAnAlreadyAnnouncedConfirmationIsNotRepeated() {
        let race = weekend([.race: at(-4)])
        let end = at(-0.5)
        XCTAssertEqual(plan([race], confirmed: ["14-gp": end], announced: ["14-gp": end]), [])
    }

    func testAConfirmedFinishDueNowBecomesAnImmediateNotification() {
        let session = weekend([.sprint: at(-4)]).allSessions[0]
        let alert = SessionAlert(fireAt: now, session: session, kind: .safeToWatch)
        let request = SessionAlertScheduler.request(for: alert, at: now.addingTimeInterval(1))
        XCTAssertNotNil(request)
        XCTAssertNil(request?.trigger, "A confirmed finish is delivered now, not dropped as a past trigger")
    }

    func testAMissedStartWarningIsStillDroppedByTheNotificationAdapter() {
        let session = weekend([.sprint: at(0.5)]).allSessions[0]
        let alert = SessionAlert(fireAt: now, session: session, kind: .startingSoon(lead: halfAnHour))
        XCTAssertNil(SessionAlertScheduler.request(for: alert, at: now.addingTimeInterval(1)))
    }

    func testAFinishTheUserOptedOutOfIsStillReportedSoItCanBeAbsorbed() {
        // Not planned, but still unannounced: the scheduler records it so that turning alerts on
        // later does not replay every finish from the last day at once.
        let race = weekend([.race: at(-4)])
        let confirmed = ["14-gp": at(-0.5)]

        XCTAssertEqual(plan([race], confirmed: confirmed,
                            preferences: preferences(announceSafeToWatch: false)), [])
        XCTAssertEqual(SessionAlertPlanner.unannouncedFinishes(
            at: now, weekends: [race], confirmedEndDates: confirmed, announcedEndDates: [:]
        ).map(\.id), ["14-gp"])
    }

    func testAFutureOrPreviousSeasonEndCannotDeclareTheSessionSafe() {
        let race = weekend([.race: at(-4)])
        XCTAssertEqual(plan([race], confirmed: ["14-gp": at(1)]), [])
        XCTAssertEqual(plan([race], confirmed: ["14-gp": at(-5)]), [])
    }

    // MARK: - What the preferences turn off

    func testTurningOffTheStartWarningLeavesOnlyTheAllClear() {
        let alerts = plan([weekend([.race: at(-4)])], confirmed: ["14-gp": at(-0.5)],
                          preferences: preferences(startLead: nil))

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

        XCTAssertEqual(alerts.map(\.session.kind), [.race])
    }

    // MARK: - The edges

    func testASessionStartingInsideTheLeadTimeGetsNoWarningAtAll() {
        // Ten minutes away, with a thirty minute lead. Firing now would deliver "starts in 30
        // minutes" ten minutes beforehand, which is worse than saying nothing.
        let alerts = plan([weekend([.race: at(1.0 / 6.0)])])

        XCTAssertEqual(alerts, [])
    }

    func testAnUnconfirmedSessionPastItsEstimatedEndIsNotAnnounced() {
        // Started 6 hours ago and past its estimated end 2.5 hours ago, but nothing confirmed it.
        let alerts = plan([weekend([.race: at(-6)])])

        XCTAssertEqual(alerts, [])
    }

    func testTheLimitKeepsTheSoonestAlertsAndDropsTheRest() {
        // Four unconfirmed sessions produce four start reminders; the cap keeps the first three.
        let alerts = plan(
            [weekend([.freePractice1: at(1), .freePractice2: at(5), .qualifying: at(9), .race: at(13)])],
            limit: 3
        )

        XCTAssertEqual(alerts.map(\.fireAt), [at(0.5), at(4.5), at(8.5)])
    }

    func testAConfirmedFinishPrecedesUpcomingStartWarnings() {
        let alerts = plan([weekend([.freePractice2: at(-2), .race: at(6.5)])],
                          confirmed: ["14-fp2": at(-0.5)])

        XCTAssertEqual(alerts.map(\.fireAt), alerts.map(\.fireAt).sorted())
        XCTAssertEqual(alerts.map(\.id), ["14-fp2-safe", "14-gp-start"])
    }

    func testAnEmptyScheduleAsksForNothing() {
        XCTAssertEqual(plan([]), [])
    }

    func testOldConfirmedFinishesAreNotAnnouncedOnLaunch() {
        XCTAssertEqual(plan([weekend([.race: at(-30)])], confirmed: ["14-gp": at(-25)]), [])
    }
}
