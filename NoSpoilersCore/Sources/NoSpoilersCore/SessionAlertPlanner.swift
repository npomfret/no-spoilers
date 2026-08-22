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
    /// Stable across replannings, because rescheduling is a wholesale replace: the pending set is
    /// rebuilt on every launch, and an id derived from `Session.id` plus the kind is what stops the
    /// same moment being delivered twice under two identities.
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
    /// **Replanned wholesale rather than topped up.** A safe-to-watch alert is placed at
    /// `SessionResolver.effectiveEndDate`, which is an estimate from the grace window until OpenF1
    /// publishes the real end — roughly half an hour after the fact on the free tier. So the fire
    /// time of an alert for a session that overran is wrong when it is first scheduled and right
    /// after the next refresh. Rescheduling everything on each launch and activation is what makes
    /// that self-correcting; incremental scheduling would leave the first, wrong answer in place.
    ///
    /// - Parameters:
    ///   - now: the current moment.
    ///   - weekends: the schedule, in any order.
    ///   - confirmedEndDates: authoritative end times by `Session.id`, from `SessionEndConfirmer`.
    ///   - preferences: what the user asked to be told.
    ///   - limit: how many to keep. The OS cap belongs to the caller.
    public static func plan(
        at now: Date,
        weekends: [RaceWeekend],
        confirmedEndDates: [String: Date],
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

            case .sessionEnd(let session):
                guard preferences.announceSafeToWatch,
                      preferences.kinds.contains(session.kind) else { continue }
                alerts.append(
                    SessionAlert(fireAt: boundary.date, session: session, kind: .safeToWatch)
                )

            case .weekendArchived:
                // Nothing to say. A weekend ageing out of the recently-finished window changes what
                // the app opens on and is worth a widget redraw, but waking someone up for it is
                // not.
                continue
            }
        }

        // Sorted again rather than trusted: the boundaries arrive in order but a start alert is
        // moved back by its lead time, which can reorder it past an earlier session's end.
        return Array(alerts.sorted { $0.fireAt < $1.fireAt }.prefix(limit))
    }
}
