import Foundation

/// When a widget timeline should redraw itself, and when it should come back for more.
///
/// Produced by `TimelinePlanner.plan(at:...)`. Only the planner constructs one — the memberwise
/// initialiser is deliberately not `public` — so a plan in hand is always internally consistent.
public struct TimelinePlan: Equatable, Sendable {
    /// The moments to build entries for, in order, after the cap. Always starts with the `now` the
    /// plan was made at, so a timeline always has something to show immediately.
    public let entryDates: [Date]

    /// How many boundaries were found before the cap was applied. Equal to `entryDates.count`
    /// unless the plan was truncated, which is what makes it worth logging.
    public let boundaryCount: Int

    /// The far edge of the plan: `now + horizon`.
    public let horizon: Date

    /// When WidgetKit should ask for a new timeline — the `.after(_:)` date.
    public let reloadAt: Date

    /// Whether the cap dropped boundaries that fell inside the horizon.
    ///
    /// Computed rather than stored, so it cannot disagree with the two counts it is derived from.
    public var truncated: Bool { entryDates.count < boundaryCount }
}

/// Decides what a widget timeline contains and when it is rebuilt.
///
/// ## Why this is here and not in the widget
///
/// It used to be in `NoSpoilersWidget.swift`, reading `Date()` from inside itself, which made every
/// decision below unassertable: the horizon, which boundaries fall inside it, whether the cap bit,
/// and which of two reload dates the timeline is given all follow from that one call.
///
/// That mattered more here than it would elsewhere, because **this is the part of the product whose
/// mistakes are invisible**. A wrong reload date shows stale content in silence — the app is not
/// running, nothing is attached, and "showing last week" looks exactly like "nothing happened".
/// Proving the reload fires at all took a purpose-built 40-session fixture, a booted simulator and a
/// nine-minute wait (the method is in `docs/guides/testing.md`); the arithmetic those minutes were
/// spent on is now a millisecond away in `TimelinePlannerTests`.
///
/// The truncation branch is the concrete case. Before 2026-08-17 it had **never executed** — the
/// real feed yields ~4 boundaries against a cap of 24 — so the reload date used when a timeline
/// overflows had never once been the one a widget was given.
///
/// `now` is a parameter rather than a clock abstraction. There is one function that needs the
/// current moment and one caller that has it; `SessionResolver.status(for:at:nextSession:...)` is
/// the established pattern for exactly this, and it is testable for exactly this reason.
///
/// `horizon` and `maxEntries` are parameters and are not defaulted. They are WidgetKit's limits
/// rather than domain facts, so they stay owned by the widget target that has to live with them —
/// and passing them in is what lets a test drive the cap without building forty sessions.
public enum TimelinePlanner {

    /// Plans a timeline as of `now`.
    ///
    /// - Parameters:
    ///   - now: the current moment. Always the plan's first entry.
    ///   - weekends: the schedule to draw boundaries from, in any order.
    ///   - confirmedEndDates: authoritative session end times by `Session.id`, from `SessionEndConfirmer`.
    ///   - horizon: how far ahead to plan. Also the reload interval when the cap does not bite.
    ///   - maxEntries: backstop on the entry count.
    public static func plan(
        at now: Date,
        weekends: [RaceWeekend],
        confirmedEndDates: [String: Date],
        horizon: TimeInterval,
        maxEntries: Int
    ) -> TimelinePlan {
        let horizonDate = now.addingTimeInterval(horizon)
        let boundaries = boundaryDates(
            after: now,
            upTo: horizonDate,
            weekends: weekends,
            confirmedEndDates: confirmedEndDates
        )
        let kept = Array(boundaries.prefix(maxEntries))

        // `boundaryDates` always seeds `now`, so an empty plan would mean the widget renders
        // nothing at all. That is a programming error, not a data state.
        guard let lastKept = kept.last else {
            preconditionFailure("boundaryDates must always emit at least the current moment")
        }

        // The reload is what keeps a sparse timeline honest. `.atEnd` used to mean December, so a
        // widget on a device where the app was never reopened computed its timeline once and never
        // looked at the cache again. Coming back at the horizon bounds staleness to `horizon`
        // whatever the feed contains — including the off-season, where the only entry is `now`.
        // If the cap truncated the list, come back at the last boundary kept instead, so the widget
        // is never left showing state it has already outlived.
        //
        // Known gap, noted 2026-09-05 and not closed: the reload is asked for at the same instant
        // the last entry is due, and `.after(_:)` is "not before". A late reload leaves that last
        // entry on screen for however late WidgetKit is. Planning entries past the reload date
        // would close it; nobody has yet seen it in the wild, so it is not built.
        let truncated = kept.count < boundaries.count

        return TimelinePlan(
            entryDates: kept,
            boundaryCount: boundaries.count,
            horizon: horizonDate,
            reloadAt: truncated ? lastKept : horizonDate
        )
    }

    /// The moments inside the horizon at which the widget should redraw.
    ///
    /// The traversal itself lives in `ScheduleBoundaries`, which is shared with everything else
    /// that has to know when the picture changes. What is left here is the widget's own part: seed
    /// the current moment so a timeline always has something to show immediately, drop anything
    /// past the horizon, and reduce to bare instants.
    ///
    /// Deduplicated, because boundaries collide routinely — `SessionResolver.effectiveEndDate`
    /// clamps an end to the next session's start, so back-to-back sessions produce the same instant
    /// twice — and a timeline entry is a picture, where one picture is enough. Callers that need to
    /// tell those two events apart take the boundaries instead.
    ///
    /// The horizon is **inclusive**: a session starting exactly on it is planned for, since
    /// excluding it would archive an entry that is wrong from the moment the timeline is handed
    /// over.
    private static func boundaryDates(
        after now: Date,
        upTo horizon: Date,
        weekends: [RaceWeekend],
        confirmedEndDates: [String: Date]
    ) -> [Date] {
        let withinHorizon = ScheduleBoundaries
            .all(after: now, weekends: weekends, confirmedEndDates: confirmedEndDates)
            .map(\.date)
            .filter { $0 <= horizon }

        return Set(([now] + withinHorizon).map(\.timeIntervalSinceReferenceDate))
            .map(Date.init(timeIntervalSinceReferenceDate:))
            .sorted()
    }
}
