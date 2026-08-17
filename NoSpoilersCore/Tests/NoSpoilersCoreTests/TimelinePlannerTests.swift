import XCTest
@testable import NoSpoilersCore

/// The widget's timeline plan, which used to be unassertable because it read `Date()` from inside
/// itself.
///
/// These are the cheap version of what `tasks/19-widget-timeline-too-large.md` needed a built
/// fixture, a booted simulator and a nine-minute wait to watch once. The truncation branch below
/// had never executed at all — in production or in testing — until that experiment forced it.
final class TimelinePlannerTests: XCTestCase {

    private let now = Date(timeIntervalSinceReferenceDate: 0)
    private let horizon: TimeInterval = 48 * 3600

    private func at(_ hours: Double) -> Date { now.addingTimeInterval(hours * 3600) }

    private func weekend(_ sessions: [SessionKind: Date], round: Int = 14) -> RaceWeekend {
        RaceWeekend(round: round, name: "Belgian", location: "Spa-Francorchamps", sessions: sessions)
    }

    private func plan(
        _ weekends: [RaceWeekend],
        confirmed: [String: Date] = [:],
        horizon: TimeInterval? = nil,
        maxEntries: Int = 24
    ) -> TimelinePlan {
        TimelinePlanner.plan(
            at: now,
            weekends: weekends,
            confirmedEndDates: confirmed,
            horizon: horizon ?? self.horizon,
            maxEntries: maxEntries
        )
    }

    // MARK: - The reload date

    func testUnderTheCapTheWidgetComesBackAtTheHorizonExactly() {
        // A race at +2h ends effectively at +5.5h (7200s duration + 5400s race grace), and the
        // weekend's recently-finished window expires 24h after that.
        let result = plan([weekend([.race: at(2)])])

        XCTAssertEqual(result.entryDates, [now, at(2), at(5.5), at(29.5)])
        XCTAssertFalse(result.truncated)
        XCTAssertEqual(result.reloadAt, at(48), "an untruncated plan reloads at the horizon")
        XCTAssertEqual(result.reloadAt, result.horizon)
    }

    func testTheCapTruncatesAndTheWidgetComesBackAtTheLastEntryItKept() {
        // The branch that had never run: with boundaries dropped, reloading at the horizon would
        // leave the widget showing state it had already outlived for up to 48 hours.
        let result = plan([weekend([.race: at(2)])], maxEntries: 2)

        XCTAssertEqual(result.entryDates, [now, at(2)])
        XCTAssertEqual(result.boundaryCount, 4, "two boundaries fell inside the horizon and were dropped")
        XCTAssertTrue(result.truncated)
        XCTAssertEqual(result.reloadAt, at(2), "reload at the last entry kept, not the horizon")
        XCTAssertNotEqual(result.reloadAt, result.horizon)
    }

    func testOffSeasonPlansOneEntryAndStillComesBack() {
        // The regression this guards: `.atEnd` on a single-entry timeline meant a widget that
        // computed itself once in December and never looked at the cache again.
        let result = plan([])

        XCTAssertEqual(result.entryDates, [now])
        XCTAssertFalse(result.truncated)
        XCTAssertEqual(result.reloadAt, at(48))
        XCTAssertGreaterThan(result.reloadAt, now, "a reload date in the past never fires")
    }

    func testAWeekendEntirelyInThePastContributesNoBoundaries() {
        let result = plan([weekend([.race: at(-96)])])

        XCTAssertEqual(result.entryDates, [now], "now is always planned for, even with nothing to show")
        XCTAssertEqual(result.reloadAt, at(48))
    }

    // MARK: - The horizon's edge

    func testASessionExactlyOnTheHorizonIsPlannedFor() {
        // Inclusive on purpose: excluding it archives an entry that is already wrong at the moment
        // the timeline is handed over.
        let result = plan([weekend([.race: at(6)])], horizon: 6 * 3600)

        XCTAssertEqual(result.entryDates, [now, at(6)])
        XCTAssertEqual(result.reloadAt, at(6), "the boundary and the horizon coincide")
    }

    func testASessionPastTheHorizonIsNot() {
        let result = plan([weekend([.race: at(6.5)])], horizon: 6 * 3600)

        XCTAssertEqual(result.entryDates, [now])
    }

    // MARK: - Boundary sources

    func testBackToBackSessionsProduceOneBoundaryNotTwo() {
        // `SessionResolver.effectiveEndDate` clamps a session's end to the next one's start, so an
        // end and a start land on the same instant routinely. Duplicate entry dates would be
        // wasted archived views at best.
        let result = plan([weekend([.freePractice1: at(1), .qualifying: at(2)])])

        // now, fp1 start, fp1 end == quali start (once), quali end at +3.5h, weekend expiry +24h.
        XCTAssertEqual(result.entryDates, [now, at(1), at(2), at(3.5), at(27.5)])
        XCTAssertEqual(Set(result.entryDates).count, result.entryDates.count)
    }

    func testEntryDatesAreSortedAcrossWeekendsGivenInAnyOrder() {
        let later = weekend([.race: at(30)], round: 15)
        let sooner = weekend([.race: at(2)], round: 14)

        let result = plan([later, sooner])

        XCTAssertEqual(result.entryDates, result.entryDates.sorted())
        XCTAssertEqual(result.entryDates.first, now)
    }

    func testAConfirmedEndMovesTheBoundaryOffTheGraceEstimate() {
        // The confirmed end from OpenF1 replaces the grace-window estimate entirely, which moves
        // both the end boundary and the weekend's 24h expiry that hangs off it. Threading this
        // through is what stops the widget calling a race live for 90 minutes after it finished.
        let race = Session(round: 14, grandPrixName: "Belgian Grand Prix",
                           location: "Spa-Francorchamps", kind: .race, startsAt: at(2))
        let result = plan([weekend([.race: at(2)])], confirmed: [race.id: at(4)])

        XCTAssertEqual(result.entryDates, [now, at(2), at(4), at(28)])
        XCTAssertFalse(result.entryDates.contains(at(5.5)), "the grace estimate must not survive a confirmation")
    }
}
