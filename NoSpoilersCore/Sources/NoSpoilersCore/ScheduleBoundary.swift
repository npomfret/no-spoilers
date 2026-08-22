import Foundation

/// A moment at which what the product should be showing — or saying — changes.
///
/// Three things move the picture: a session starting, a session becoming effectively over and
/// therefore safe to watch, and a finished weekend ageing out of the 24-hour window in which the
/// app still opens on it.
///
/// **This is deliberately not a bare `Date`.** The widget only needs the instant, and that is all
/// `TimelinePlanner` takes from it, but anything that speaks to the user — a notification, an
/// intent's answer — has to know which session moved and which way. Two traversals over the same
/// schedule producing two answers to "when is this session over" is the drift the core rules call
/// a correctness issue, so there is one traversal and the callers take what they need.
public struct ScheduleBoundary: Equatable {
    public enum Event: Equatable {
        /// `session` starts at this moment.
        case sessionStart(Session)
        /// `session` is effectively over: `SessionResolver.effectiveEndDate`, which is the
        /// confirmed end where OpenF1 has given us one and the end of the grace window otherwise,
        /// clamped to the next session starting.
        case sessionEnd(Session)
        /// The weekend of this round leaves the 24-hour recently-finished window.
        ///
        /// Carries the round rather than the weekend: it is the only part any caller has wanted,
        /// and a whole `RaceWeekend` in an `Equatable` case makes every comparison walk its
        /// sessions.
        case weekendArchived(round: Int)
    }

    public let date: Date
    public let event: Event

    public init(date: Date, event: Event) {
        self.date = date
        self.event = event
    }
}

public enum ScheduleBoundaries {

    /// Every boundary strictly after `now`, in chronological order.
    ///
    /// Strictly after: a boundary at `now` has already happened as far as anything downstream is
    /// concerned — the widget seeds its own current moment separately, and an alert for a session
    /// that has just started is late rather than due.
    ///
    /// Boundaries collide routinely and are **not** deduplicated here, because two different events
    /// landing on the same instant is exactly what a caller may need to tell apart:
    /// `effectiveEndDate` clamps a session's end to the next session's start, so back-to-back
    /// sessions put an end and a start on the same second. `TimelinePlanner` dedupes the dates
    /// because a timeline entry is a picture and one picture is enough.
    ///
    /// Weekends with no sessions are skipped rather than asked when they ended —
    /// `RaceWeekendResolver.effectiveEndDate` traps on those by design.
    public static func all(
        after now: Date,
        weekends: [RaceWeekend],
        confirmedEndDates: [String: Date]
    ) -> [ScheduleBoundary] {
        var boundaries: [ScheduleBoundary] = []

        for weekend in weekends where !weekend.allSessions.isEmpty {
            let endTime = RaceWeekendResolver.effectiveEndDate(
                of: weekend,
                confirmedEndDates: confirmedEndDates
            )
            let archived = endTime.addingTimeInterval(24 * 3600)
            if archived > now {
                boundaries.append(
                    ScheduleBoundary(date: archived, event: .weekendArchived(round: weekend.round))
                )
            }
        }

        // Flattened across weekends and sorted, not per-weekend: `effectiveEndDate` needs the next
        // session chronologically, and the last session of one weekend is followed by the first of
        // the next.
        let allSessions = weekends.flatMap(\.allSessions).sorted { $0.startsAt < $1.startsAt }
        for index in allSessions.indices {
            let session = allSessions[index]
            let nextSession = index + 1 < allSessions.count ? allSessions[index + 1] : nil

            if session.startsAt > now {
                boundaries.append(
                    ScheduleBoundary(date: session.startsAt, event: .sessionStart(session))
                )
            }

            let end = SessionResolver.effectiveEndDate(
                for: session,
                nextSession: nextSession,
                confirmedEndAt: confirmedEndDates[session.id]
            )
            if end > now {
                boundaries.append(ScheduleBoundary(date: end, event: .sessionEnd(session)))
            }
        }

        return boundaries.sorted { $0.date < $1.date }
    }
}
