import Foundation

/// A moment at which what the product should be showing — or saying — changes.
///
/// The scheduled start, an unconfirmed estimated end, an authoritative finish, and calendar
/// archival are separate events. Passing an estimate never certifies a session as safe to watch.
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
        /// An authoritative end has been recorded for this session.
        case sessionEnd(Session)
        /// The calendar estimate passed without a confirmed finish.
        case sessionUnconfirmed(Session)
        /// The weekend of this round leaves the 24-hour calendar archive window.
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
    /// An estimated window is capped at the next scheduled start, so back-to-back
    /// sessions put an uncertainty boundary and a start on the same second. `TimelinePlanner` dedupes the dates
    /// because a timeline entry is a picture and one picture is enough.
    ///
    /// Weekends with no sessions are skipped rather than asked when they ended —
    /// `RaceWeekendResolver.archiveDate` traps on those by design.
    public static func all(
        after now: Date,
        weekends: [RaceWeekend],
        confirmedEndDates: [String: Date]
    ) -> [ScheduleBoundary] {
        var boundaries: [ScheduleBoundary] = []

        for weekend in weekends where !weekend.allSessions.isEmpty {
            let archived = RaceWeekendResolver.archiveDate(of: weekend, confirmedEndDates: confirmedEndDates)
            if archived > now {
                boundaries.append(
                    ScheduleBoundary(date: archived, event: .weekendArchived(round: weekend.round))
                )
            }
        }

        // Estimates use the next chronological scheduled start, including across weekends.
        let allSessions = weekends.flatMap(\.allSessions).sorted { $0.startsAt < $1.startsAt }
        for index in allSessions.indices {
            let session = allSessions[index]
            let nextSession = index + 1 < allSessions.count ? allSessions[index + 1] : nil

            if session.startsAt > now {
                boundaries.append(
                    ScheduleBoundary(date: session.startsAt, event: .sessionStart(session))
                )
            }

            if let confirmed = confirmedEndDates[session.id], confirmed >= session.startsAt {
                if confirmed > now {
                    boundaries.append(ScheduleBoundary(date: confirmed, event: .sessionEnd(session)))
                }
            } else {
                let estimate = SessionResolver.estimatedEndDate(for: session, nextSession: nextSession)
                if estimate > now {
                    boundaries.append(ScheduleBoundary(date: estimate, event: .sessionUnconfirmed(session)))
                }
            }
        }

        return boundaries.sorted { $0.date < $1.date }
    }
}
