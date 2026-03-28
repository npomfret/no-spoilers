import Foundation

public enum RaceWeekendResolver {
    public static func firstActiveWeekend(
        in weekends: [RaceWeekend],
        at now: Date,
        confirmedEndDates: [String: Date] = [:]
    ) -> RaceWeekend? {
        sorted(weekends).first { weekend in
            firstNonFinishedSession(in: weekend, at: now, confirmedEndDates: confirmedEndDates) != nil
        }
    }

    public static func currentWeekend(
        in weekends: [RaceWeekend],
        at now: Date,
        imminentWindow: TimeInterval = 5 * 86_400,
        confirmedEndDates: [String: Date] = [:]
    ) -> RaceWeekend? {
        sorted(weekends).first { weekend in
            guard firstNonFinishedSession(in: weekend, at: now, confirmedEndDates: confirmedEndDates) != nil else {
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

    public static func firstNonFinishedSession(
        in weekend: RaceWeekend,
        at now: Date,
        confirmedEndDates: [String: Date] = [:]
    ) -> Session? {
        let sessions = weekend.allSessions
        guard let index = sessions.indices.first(where: { index in
            status(for: sessions, index: index, at: now, confirmedEndDates: confirmedEndDates) != .finished
        }) else {
            return nil
        }
        return sessions[index]
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
