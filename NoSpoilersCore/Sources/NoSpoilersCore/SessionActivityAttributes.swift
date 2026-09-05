import Foundation

/// Which half of the session's life a Live Activity is in.
///
/// Part of the activity's *content* state rather than its attributes because it changes while one
/// activity runs: a session that was upcoming when the app was last open is live when it is next
/// opened, and that is an update to the same activity rather than a different one.
///
/// **Outside the `os(iOS)` guard, and a top-level type, on purpose.** The package's tests run on
/// macOS, where ActivityKit does not exist, and `SessionActivityDisplay` below is the one decision
/// in this feature that a test can reach. Encoded as its raw string either way, so an activity
/// started by a build that nested this in `SessionActivityAttributes` still decodes.
public enum SessionActivityPhase: String, Codable, Hashable {
    case upcoming
    case live
}

/// What the extension draws for an activity: the phase the app last pushed, advanced by one step
/// when the clock has passed the content's `staleDate`.
///
/// **This is the half of the stale date that was never built.** A Live Activity is updated by the
/// app from the foreground and by nothing else — no push, no background task — so the phase in the
/// content state is only true until the instant it names. ActivityKit does not relabel or dim a
/// stale activity on its own; it re-renders the view with `context.isStale` set and leaves the
/// drawing to us. Until 2026-09-05 nothing read it, and a Lock Screen said *In Progress* an hour
/// after the session's grace window closed.
///
/// A stale upcoming activity is a session that has started; a stale live one is a session that
/// has ended. Both are exactly what the Home Screen widget and the safe-to-watch alert say at the
/// same instants, so drawing them here is consistency rather than a new claim.
public enum SessionActivityDisplay: Hashable {
    case upcoming
    case live
    case finished

    public init(phase: SessionActivityPhase, isStale: Bool) {
        switch (phase, isStale) {
        case (.upcoming, false): self = .upcoming
        case (.upcoming, true):  self = .live
        case (.live, false):     self = .live
        case (.live, true):      self = .finished
        }
    }
}

#if os(iOS)
import ActivityKit

/// What a Live Activity for a session carries, shared by the app that starts it and the extension
/// that draws it.
///
/// **In Core because two targets need the same type.** ActivityKit matches a running activity to
/// its `ActivityConfiguration` by this type's identity, so the app and the widget extension must
/// be looking at one declaration — a copy in each would compile and then never render. It is the
/// same reason `SessionAlertDefaults` moved here when the Mac app got alerts.
///
/// Guarded by `os(iOS)` rather than `canImport`: there is no ActivityKit on macOS and the package
/// builds for both. `Strings` already branches this way.
///
/// **Three fields, and never a fourth.** This is content pushed onto a locked screen that the
/// reader cannot decline to look at — the same class of surface as the alert copy — so it shows
/// what every other family already leads with: the Grand Prix, the session, a clock. Nothing about
/// a result has any way in here, and nothing about one is to be given one.
/// `Hashable` is ours, not ActivityKit's: `ActivityAttributes` requires only `Codable`, and
/// `SessionActivityController` has to be able to ask whether a running activity is for the session
/// the planner now names or for one it has outlived.
public struct SessionActivityAttributes: ActivityAttributes, Hashable {

    public struct ContentState: Codable, Hashable {
        public let phase: SessionActivityPhase

        /// Both instants travel, whichever phase we are in. `Text(timerInterval:)` takes a range,
        /// and a range needs both ends even when only one of them is being counted to.
        public let startsAt: Date

        /// `SessionResolver.effectiveEndDate`, never `Session.endsAt`. The distinction is
        /// user-visible: a race carries a 90-minute grace period, so the scheduled end is not the
        /// moment anything else in the product calls it over.
        public let endsAt: Date

        public init(phase: SessionActivityPhase, startsAt: Date, endsAt: Date) {
            self.phase = phase
            self.startsAt = startsAt
            self.endsAt = endsAt
        }

        /// The instant this content stops being true.
        ///
        /// Handed to ActivityKit as the activity's `staleDate`, which is the only honest answer to
        /// the one thing this feature cannot do on its own. **A Live Activity does not re-render
        /// with the clock** — the system redraws it when the app pushes an update, and the app
        /// cannot push one from the background without a server. So an activity that says "starts
        /// in" is still saying it a minute after the session began, unless the extension does
        /// something with the fact that it is stale.
        ///
        /// It does: when this instant passes, ActivityKit re-renders the view with
        /// `context.isStale` set, and `SessionActivityDisplay` turns that into the next phase —
        /// upcoming becomes live, live becomes finished. The system itself neither dims nor
        /// relabels anything; a stale activity that reads only `phase` keeps saying what it said.
        public var staleDate: Date {
            switch phase {
            case .upcoming: return startsAt
            case .live:     return endsAt
            }
        }
    }

    /// The session's identity. Changing any of these means a different activity, not an update.
    public let round: Int
    public let grandPrixName: String
    public let sessionName: String

    public init(round: Int, grandPrixName: String, sessionName: String) {
        self.round = round
        self.grandPrixName = grandPrixName
        self.sessionName = sessionName
    }
}

public extension FeaturedSession {
    /// The identity half of this plan, as ActivityKit wants it.
    var activityAttributes: SessionActivityAttributes {
        SessionActivityAttributes(
            round: session.round,
            grandPrixName: session.grandPrixName,
            sessionName: session.kind.displayName
        )
    }

    /// The changing half of this plan, as ActivityKit wants it.
    ///
    /// The mapping lives here, once, so the planner stays a pure function over the schedule and
    /// knows nothing about ActivityKit — the same split `SessionAlertPlanner` keeps from
    /// `UNUserNotificationCenter`.
    var activityContentState: SessionActivityAttributes.ContentState {
        SessionActivityAttributes.ContentState(
            phase: phase == .live ? .live : .upcoming,
            startsAt: startsAt,
            endsAt: endsAt
        )
    }
}
#endif
