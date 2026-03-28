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
    public static func status(
        for session: Session,
        at now: Date,
        nextSession: Session? = nil,
        confirmedEndAt: Date? = nil
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
}
