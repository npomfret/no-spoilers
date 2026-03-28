import Foundation

public enum SessionStatus {
    case upcoming
    case inProgress
    case finished
}

public struct SessionResolver {
    /// Resolve a session's status relative to `now`.
    /// Pass `nextSession` (the next chronological session) to enable the
    /// "next session started → this one is finished" override rule.
    public static func status(
        for session: Session,
        at now: Date,
        nextSession: Session? = nil
    ) -> SessionStatus {
        if now < session.startsAt { return .upcoming }
        // If the next session has started, this one must be over.
        if let next = nextSession, now >= next.startsAt { return .finished }
        let graceEnd = session.endsAt + session.kind.gracePeriod
        if now < graceEnd { return .inProgress }
        return .finished
    }
}
