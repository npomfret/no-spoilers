import Foundation

public enum SessionStatus {
    case upcoming
    case inProgress
    case finished
}

public struct SessionResolver {
    /// Resolve a session's status relative to `now`.
    ///
    /// - `nextSession`: the next chronological session; enables the
    ///   "next session started → this one is finished" override rule.
    /// - `confirmedEndAt`: authoritative actual end time from an external
    ///   source (e.g. OpenF1). When provided, replaces the grace-window
    ///   estimate entirely — the session transitions to `.finished` exactly
    ///   when `now >= confirmedEndAt`.
    ///
    /// Neither parameter is defaulted, deliberately. Both were, and iOS quietly
    /// omitted `confirmedEndAt` at every call site — so the confirmed end times
    /// the app was polling for and storing were never actually used to decide
    /// anything, and two views on the same screen disagreed about whether a
    /// weekend was over. Passing `nil` is a fine answer; not noticing the
    /// question is not.
    public static func status(
        for session: Session,
        at now: Date,
        nextSession: Session?,
        confirmedEndAt: Date?
    ) -> SessionStatus {
        if now < session.startsAt { return .upcoming }
        // If the next session has started, this one must be over.
        if let next = nextSession, now >= next.startsAt { return .finished }
        // Authoritative end time from external source takes priority.
        if let confirmed = confirmedEndAt {
            return now >= confirmed ? .finished : .inProgress
        }
        // Conservative fallback: stay inProgress through the grace window.
        let graceEnd = session.endsAt + session.kind.gracePeriod
        if now < graceEnd { return .inProgress }
        return .finished
    }

    /// When a session is actually considered over.
    ///
    /// This is not `Session.endsAt`, which is only `startsAt + kind.defaultDuration` — the
    /// *scheduled* end. The effective end is the confirmed end time if we have one, otherwise the
    /// end of the grace window, and never later than the next session starting.
    ///
    /// The distinction is user-visible: the race grace period is 90 minutes, so labelling a
    /// finished race from `endsAt` said "finished 1h 40m ago" at the moment this considers it just
    /// over. Both apps used to do exactly that while the widget did it correctly, which is why
    /// this now lives here and all three call it.
    public static func effectiveEndDate(
        for session: Session,
        nextSession: Session?,
        confirmedEndAt: Date?
    ) -> Date {
        let end = confirmedEndAt ?? (session.endsAt + session.kind.gracePeriod)
        guard let nextSession else { return end }
        return min(nextSession.startsAt, end)
    }
}
