import Foundation

/// The one session the product is talking about right now, and which side of its start we are on.
///
/// "Featured" rather than "next", because a session that is already running is the one that
/// matters and is not next by any reading. Produced by `FeaturedSessionPlanner.plan(at:...)`,
/// which is the only thing that constructs one.
public struct FeaturedSession: Equatable {
    /// Calendar presentation, with an explicit state after the estimated window passes.
    public enum Phase: Equatable {
        /// The session has not started. The interesting instant is `startsAt`.
        case upcoming
        /// The scheduled window is open; no actual start is asserted.
        case live
        case unconfirmed
    }

    public let session: Session
    public let phase: Phase

    /// The weekend's flag, as `RaceWeekend.countryCode` gives it: nil when the feed names a Grand
    /// Prix the mapping does not cover, which `FlagImage` draws as the chequered flag.
    ///
    /// **Here because a `Session` does not know its country.** The session carries the Grand
    /// Prix's name and round, and the country is a fact about the weekend; every other surface
    /// that draws a flag has the `RaceWeekend` in hand. The Live Activity does not — it is handed
    /// this plan and nothing else — so the plan carries the one weekend fact it needs.
    public let countryCode: String?

    public let startsAt: Date

    /// Calendar estimate, used for staleness only; not proof that a session finished.
    public let endsAt: Date

    public init(session: Session, phase: Phase, countryCode: String?, startsAt: Date, endsAt: Date) {
        self.session = session
        self.phase = phase
        self.countryCode = countryCode
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
/// `SessionResolver` owns status and timing. A passed calendar estimate keeps a session featured
/// with an unconfirmed finish until confirmation arrives or the weekend leaves the archive window.
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
        let candidates = weekends.compactMap { weekend -> (RaceWeekend, Session)? in
            guard !weekend.allSessions.isEmpty,
                  now < RaceWeekendResolver.archiveDate(of: weekend, confirmedEndDates: confirmedEndDates),
                  let session = RaceWeekendResolver.firstNonFinishedSession(
                    in: weekend, at: now, confirmedEndDates: confirmedEndDates
                  ) else { return nil }
            return (weekend, session)
        }
        let selected = candidates.filter { $0.1.startsAt <= now }.max { $0.1.startsAt < $1.1.startsAt }
            ?? candidates.filter { $0.1.startsAt > now }.min { $0.1.startsAt < $1.1.startsAt }
        guard let (weekend, session) = selected else { return nil }
        let sessions = weekend.allSessions
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else {
            preconditionFailure("Featured session must belong to its weekend")
        }
        let next = index + 1 < sessions.count ? sessions[index + 1] : nil
        let status = SessionResolver.status(for: session, at: now, nextSession: next,
                                            confirmedEndAt: confirmedEndDates[session.id])
        if status == .upcoming && session.startsAt.timeIntervalSince(now) > lookAhead { return nil }
        let phase: FeaturedSession.Phase
        switch status {
        case .upcoming: phase = .upcoming
        case .inProgress: phase = .live
        case .unconfirmed: phase = .unconfirmed
        case .finished: preconditionFailure("A confirmed finished session cannot be featured")
        }
        return FeaturedSession(
            session: session, phase: phase, countryCode: weekend.countryCode,
            startsAt: session.startsAt,
            endsAt: SessionResolver.estimatedEndDate(for: session, nextSession: next)
        )
    }
}
