import Foundation

public enum SessionStatus {
    case upcoming
    /// Inside the scheduled window; not a confirmed actual start.
    case inProgress
    case unconfirmed
    case finished
}

public struct SessionResolver {
    /// A scheduled start or a following session's scheduled start cannot prove a finish.
    /// Only an authoritative end belonging to this session can produce `.finished`.
    public static func status(
        for session: Session,
        at now: Date,
        nextSession: Session?,
        confirmedEndAt: Date?
    ) -> SessionStatus {
        if now < session.startsAt { return .upcoming }
        if let confirmed = confirmedEndAt, confirmed >= session.startsAt {
            return now >= confirmed ? .finished : .inProgress
        }
        return now < estimatedEndDate(for: session, nextSession: nextSession)
            ? .inProgress : .unconfirmed
    }

    /// Calendar boundary for moving from the scheduled window to an unconfirmed finish.
    /// It is not a finish time and must never be used for a Finished label or an all-clear.
    public static func estimatedEndDate(for session: Session, nextSession: Session?) -> Date {
        let estimate = session.endsAt + session.kind.gracePeriod
        guard let nextSession else { return estimate }
        return min(nextSession.startsAt, estimate)
    }

    /// Actual finish timing, used only after status has resolved to `.finished`.
    /// Refuses an absent or previous-season record instead of supplying an estimate.
    public static func effectiveEndDate(
        for session: Session,
        nextSession: Session?,
        confirmedEndAt: Date?
    ) -> Date {
        guard let confirmed = confirmedEndAt, confirmed >= session.startsAt else {
            preconditionFailure("A finished session requires a valid confirmed end")
        }
        return confirmed
    }
}
