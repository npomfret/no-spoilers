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
}
