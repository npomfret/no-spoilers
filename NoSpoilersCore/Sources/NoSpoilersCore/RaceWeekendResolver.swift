import Foundation

public enum RaceWeekendResolver {
    public static func firstActiveWeekend(
        in weekends: [RaceWeekend],
        at now: Date,
        confirmedEndDates: [String: Date]
    ) -> RaceWeekend? {
        sorted(weekends).first { weekend in
            !weekend.allSessions.isEmpty
                && now < archiveDate(of: weekend, confirmedEndDates: confirmedEndDates)
                && firstNonFinishedSession(in: weekend, at: now, confirmedEndDates: confirmedEndDates) != nil
        }
    }

    public static func currentWeekend(
        in weekends: [RaceWeekend],
        at now: Date,
        confirmedEndDates: [String: Date],
        imminentWindow: TimeInterval = 5 * 86_400
    ) -> RaceWeekend? {
        sorted(weekends).first { weekend in
            guard !weekend.allSessions.isEmpty,
                  now < archiveDate(of: weekend, confirmedEndDates: confirmedEndDates),
                  firstNonFinishedSession(in: weekend, at: now, confirmedEndDates: confirmedEndDates) != nil else {
                return false
            }
            guard let firstSession = weekend.allSessions.first else {
                return false
            }
            return firstSession.startsAt <= now || firstSession.startsAt.timeIntervalSince(now) <= imminentWindow
        }
    }

    public static func nextWeekend(after weekend: RaceWeekend, in weekends: [RaceWeekend]) -> RaceWeekend? {
        sorted(weekends).first { $0.round > weekend.round }
    }

    /// When a weekend is over: the effective end of its last session.
    ///
    /// Both apps carried their own verbatim copy of this, each returning `.distantPast` for a
    /// weekend with no sessions. Every caller already filters those out, so the sentinel was
    /// unreachable — and had it ever been reached it would have quietly claimed the weekend ended
    /// in the year 1, which reads as "finished" everywhere. A weekend with no sessions is not
    /// something to render around; it is a caller that skipped its filter.
    public static func effectiveEndDate(of weekend: RaceWeekend, confirmedEndDates: [String: Date]) -> Date {
        guard let last = weekend.allSessions.last else {
            preconditionFailure("Round \(weekend.round) has no sessions — filter on allSessions before asking when it ended")
        }
        return SessionResolver.effectiveEndDate(
            for: last,
            nextSession: nil,
            confirmedEndAt: confirmedEndDates[last.id]
        )
    }

    public static func firstNonFinishedSession(
        in weekend: RaceWeekend,
        at now: Date,
        confirmedEndDates: [String: Date]
    ) -> Session? {
        let sessions = weekend.allSessions
        if let index = sessions.indices.last(where: { sessions[$0].startsAt <= now }),
           status(for: sessions, index: index, at: now, confirmedEndDates: confirmedEndDates) != .finished {
            return sessions[index]
        }
        if let upcoming = sessions.first(where: { $0.startsAt > now }) { return upcoming }
        return nil
    }

    /// Calendar expiry keeps old unresolved weekends out of the current view. Archival is not
    /// evidence of completion; historic session rows retain their unconfirmed status.
    public static func archiveDate(of weekend: RaceWeekend, confirmedEndDates: [String: Date]) -> Date {
        guard let last = weekend.allSessions.last else {
            preconditionFailure("A weekend without sessions has no archive date")
        }
        let boundary: Date
        if let confirmed = confirmedEndDates[last.id], confirmed >= last.startsAt {
            boundary = confirmed
        } else {
            boundary = SessionResolver.estimatedEndDate(for: last, nextSession: nil)
        }
        return boundary.addingTimeInterval(24 * 3600)
    }

    private static func sorted(_ weekends: [RaceWeekend]) -> [RaceWeekend] {
        weekends.sorted { $0.round < $1.round }
    }

    private static func status(
        for sessions: [Session],
        index: Int,
        at now: Date,
        confirmedEndDates: [String: Date]
    ) -> SessionStatus {
        let nextSession = index + 1 < sessions.count ? sessions[index + 1] : nil
        return SessionResolver.status(
            for: sessions[index],
            at: now,
            nextSession: nextSession,
            confirmedEndAt: confirmedEndDates[sessions[index].id]
        )
    }
}
