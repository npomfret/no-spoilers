import Foundation

/// What an alert has to say.
public enum SessionAlertKind: Equatable {
    /// The session has not started yet and will in `lead`.
    case startingSoon(lead: TimeInterval)
    /// The session is over, so it is safe to watch on replay.
    ///
    /// **The one alert this product exists to send.** Everything else here is a schedule app's
    /// ordinary furniture; this is the promise being kept without the user having to look.
    case safeToWatch
}

/// One notification, decided but not yet worded.
///
/// Carries no copy. The text is target-private — only iOS schedules these — and lives in that
/// target's `Strings.swift`, so the planner stays a pure function over the schedule and the
/// wording stays somewhere a translator can find it.
public struct SessionAlert: Equatable, Identifiable {
    /// Stable across replannings so pending requests retain one identity. The scheduler also
    /// persists accepted finish timestamps to prevent announcing a delivered finish again.
    public var id: String {
        switch kind {
        case .startingSoon: return "\(session.id)-start"
        case .safeToWatch:  return "\(session.id)-safe"
        }
    }

    public let fireAt: Date
    public let session: Session
    public let kind: SessionAlertKind

    public init(fireAt: Date, session: Session, kind: SessionAlertKind) {
        self.fireAt = fireAt
        self.session = session
        self.kind = kind
    }
}

/// What the user has asked to be told about.
public struct SessionAlertPreferences: Equatable {
    /// How long before a session starts to give warning, or `nil` for no warning.
    ///
    /// Optional here is a real answer rather than missing data: "do not remind me" is a choice
    /// someone makes, and it is not the same as a lead of zero, which would fire at the moment the
    /// session began.
    public var startLead: TimeInterval?

    /// Whether to say when a session is over and safe to watch.
    public var announceSafeToWatch: Bool

    /// Which kinds of session are worth being told about at all. Practice is the reason this
    /// exists: three hours of it a weekend, and plenty of people only watch the race.
    public var kinds: Set<SessionKind>

    public init(startLead: TimeInterval?, announceSafeToWatch: Bool, kinds: Set<SessionKind>) {
        self.startLead = startLead
        self.announceSafeToWatch = announceSafeToWatch
        self.kinds = kinds
    }
}

/// Decides which notifications to have pending, and when.
///
/// Built in the shape of `TimelinePlanner`, for the same reason: `now` is a parameter rather than a
/// clock read from inside, so every decision below is assertable. The mistakes here are the
/// invisible kind — a notification that does not arrive looks exactly like a weekend where nothing
/// happened — and that is precisely the class of bug the widget's timeline used to have.
///
/// `limit` is a parameter and is not defaulted. **iOS keeps at most 64 pending local
/// notifications** and silently drops the rest, which is the platform's limit rather than a domain
/// fact, so it stays owned by the target that has to live with it — exactly as `maxEntries` is
/// owned by the widget.
public enum SessionAlertPlanner {

    /// The alerts that should be pending as of `now`, soonest first.
    ///
    /// Start reminders are scheduled in advance. All-clears are delivered only after a confirmed
    /// end has arrived, never at the grace-window estimate. Confirmations arrive after the fact,
    /// so an unannounced recent confirmation is due now. The same 24-hour window used for recently
    /// finished weekends bounds catch-up; opening the app must not announce the whole season.
    ///
    /// - Parameters:
    ///   - now: the current moment.
    ///   - weekends: the schedule, in any order.
    ///   - confirmedEndDates: authoritative end times by `Session.id`, from `SessionEndConfirmer`.
    ///   - announcedEndDates: confirmations already accepted by the OS, persisted by the scheduler.
    ///   - preferences: what the user asked to be told.
    ///   - limit: how many to keep. The OS cap belongs to the caller.
    public static func plan(
        at now: Date,
        weekends: [RaceWeekend],
        confirmedEndDates: [String: Date],
        announcedEndDates: [String: Date],
        preferences: SessionAlertPreferences,
        limit: Int
    ) -> [SessionAlert] {
        let boundaries = ScheduleBoundaries.all(
            after: now,
            weekends: weekends,
            confirmedEndDates: confirmedEndDates
        )

        var alerts: [SessionAlert] = []

        for boundary in boundaries {
            switch boundary.event {
            case .sessionStart(let session):
                guard let lead = preferences.startLead,
                      preferences.kinds.contains(session.kind) else { continue }
                let fireAt = boundary.date.addingTimeInterval(-lead)
                // A session starting inside the lead time has already missed its warning. Firing
                // now anyway would deliver "starts in 30 minutes" ten minutes beforehand, which is
                // worse than silence.
                guard fireAt > now else { continue }
                alerts.append(
                    SessionAlert(fireAt: fireAt, session: session, kind: .startingSoon(lead: lead))
                )

            case .sessionEnd, .sessionUnconfirmed, .weekendArchived:
                // Neither an estimated end nor weekend archival is proof of a session finish.
                continue
            }
        }

        if preferences.announceSafeToWatch {
            let finishes = unannouncedFinishes(at: now, weekends: weekends,
                                               confirmedEndDates: confirmedEndDates,
                                               announcedEndDates: announcedEndDates)
            for session in finishes where preferences.kinds.contains(session.kind) {
                alerts.append(SessionAlert(fireAt: now, session: session, kind: .safeToWatch))
            }
        }

        // Sorted again rather than trusted: the boundaries arrive in order but a start alert is
        // moved back by its lead time, which can reorder it past an earlier session's end.
        return Array(alerts.sorted { $0.fireAt < $1.fireAt }.prefix(limit))
    }

    /// Recent confirmed finishes not yet announced, regardless of preferences.
    ///
    /// The scheduler records the ones it could not or was not asked to announce, so turning alerts
    /// on later does not replay every finish from the last 24 hours at once.
    public static func unannouncedFinishes(
        at now: Date,
        weekends: [RaceWeekend],
        confirmedEndDates: [String: Date],
        announcedEndDates: [String: Date]
    ) -> [Session] {
        weekends.flatMap(\.allSessions).filter { session in
            guard let end = confirmedEndDates[session.id] else { return false }
            return end >= session.startsAt && end <= now
                && now.timeIntervalSince(end) < SessionEndConfirmer.confirmationWindow
                && announcedEndDates[session.id] != end
        }
    }
}
