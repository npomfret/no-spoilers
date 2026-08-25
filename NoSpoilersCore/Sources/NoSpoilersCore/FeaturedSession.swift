import Foundation

/// The one session the product is talking about right now, and which side of its start we are on.
///
/// "Featured" rather than "next", because a session that is already running is the one that
/// matters and is not next by any reading. Produced by `FeaturedSessionPlanner.plan(at:...)`,
/// which is the only thing that constructs one.
public struct FeaturedSession: Equatable {
    /// Which half of the session's life the activity is in.
    ///
    /// The two are separate because they say different things — "starts in" counts down to
    /// `startsAt`, "ends in" counts down to `endsAt` — and because the transition between them is
    /// the one moment this feature cannot render on its own. See `SessionActivityAttributes`.
    public enum Phase: Equatable {
        /// The session has not started. The interesting instant is `startsAt`.
        case upcoming
        /// The session is running. The interesting instant is `endsAt`.
        case live
    }

    public let session: Session
    public let phase: Phase

    public let startsAt: Date

    /// `SessionResolver.effectiveEndDate` — the confirmed end where OpenF1 has given us one, the
    /// end of the grace window otherwise. Never `Session.endsAt`, which is only the scheduled end.
    public let endsAt: Date

    public init(session: Session, phase: Phase, startsAt: Date, endsAt: Date) {
        self.session = session
        self.phase = phase
        self.startsAt = startsAt
        self.endsAt = endsAt
    }
}

/// Answers "what is on, or on next".
///
/// **Two callers, deliberately one implementation.** `SessionActivityController` asks so it can put
/// a countdown on the Lock Screen, and `NextSessionIntent` asks so Siri and Spotlight can say it
/// out loud. Both want the same sentence — the session running, or the next one to start — and two
/// functions computing it would be two answers the user could catch disagreeing, out loud, on the
/// same device.
///
/// Third in the shape of `TimelinePlanner`, after `SessionAlertPlanner`, and for the same reason:
/// `now` is a parameter rather than a clock read from inside, so every decision below is
/// assertable. It matters here for the usual reason — a Live Activity that never appears looks
/// exactly like a weekend with nothing on — and for one particular to it: an activity is *started*
/// from the foreground and then lives on a Lock Screen the app cannot see, so the only thing that
/// can be checked at all is the decision to start it.
///
/// It computes no boundary of its own. `ScheduleBoundaries` is the single traversal and
/// `SessionResolver` the single answer to when a session starts and is over; this reads them.
///
/// `lookAhead` is a parameter and is not defaulted, because the two callers genuinely differ.
/// **A Live Activity runs 8 hours active** and stays visible up to 4 more in a stale state, so a
/// countdown started earlier than that would be killed by the system before the session it counts
/// to; an intent has no such budget and passes `.infinity`, because someone who asks when the next
/// session is wants the answer in February as much as on a Saturday. That is a platform limit
/// rather than a domain fact, which is why it belongs to the caller — exactly as `maxEntries` is
/// owned by the widget and `limit` by the alert scheduler.
public enum FeaturedSessionPlanner {

    /// What should be on the Lock Screen as of `now`, or `nil` for nothing.
    ///
    /// A session already running always wins: it is the thing happening, and the next one to start
    /// is by definition after it. Otherwise the next session to start qualifies only if it falls
    /// inside `lookAhead` — a countdown to a session four days out is not worth a Lock Screen, and
    /// could not survive there anyway.
    ///
    /// - Parameters:
    ///   - now: the current moment.
    ///   - weekends: the schedule, in any order.
    ///   - confirmedEndDates: authoritative end times by `Session.id`, from `SessionEndConfirmer`.
    ///   - lookAhead: how far ahead a session may start and still be worth naming, or `.infinity`
    ///     for no limit. The platform's budget belongs to the caller.
    public static func plan(
        at now: Date,
        weekends: [RaceWeekend],
        confirmedEndDates: [String: Date],
        lookAhead: TimeInterval
    ) -> FeaturedSession? {
        // A weekend ageing out of the recently-finished window changes what the app opens on and
        // says nothing about any session, so it cannot be the next thing an activity cares about.
        let sessionEvents = ScheduleBoundaries
            .all(after: now, weekends: weekends, confirmedEndDates: confirmedEndDates)
            .filter { boundary in
                if case .weekendArchived = boundary.event { return false }
                return true
            }

        guard let first = sessionEvents.first else { return nil }

        switch first.event {
        case .sessionEnd(let session):
            // The next session event being an *end* means that session has already started —
            // `ScheduleBoundaries` emits a start only for sessions still to come, and
            // `effectiveEndDate` clamps an end to the next session's start, so no two sessions
            // overlap and nothing can be running behind this one.
            return FeaturedSession(
                session: session,
                phase: .live,
                startsAt: session.startsAt,
                endsAt: first.date
            )

        case .sessionStart(let session):
            guard first.date.timeIntervalSince(now) <= lookAhead else { return nil }
            return FeaturedSession(
                session: session,
                phase: .upcoming,
                startsAt: first.date,
                endsAt: effectiveEnd(of: session, in: sessionEvents)
            )

        case .weekendArchived:
            preconditionFailure("weekendArchived was filtered out above")
        }
    }

    /// The end boundary belonging to `session`.
    ///
    /// Traps rather than defaulting. A session whose start is still ahead of `now` has an end
    /// further ahead still, so `ScheduleBoundaries` has always emitted one; its absence would mean
    /// the traversal had changed underneath this, and an activity given a made-up end would count
    /// down to a moment nothing else in the product agrees with.
    private static func effectiveEnd(of session: Session, in events: [ScheduleBoundary]) -> Date {
        for boundary in events {
            if case .sessionEnd(let candidate) = boundary.event, candidate.id == session.id {
                return boundary.date
            }
        }
        preconditionFailure("no end boundary for \(session.id), whose start is still ahead of now")
    }
}
