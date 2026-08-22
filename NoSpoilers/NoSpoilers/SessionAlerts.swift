import Combine
import Foundation
import UserNotifications
import NoSpoilersCore

/// Where the alert preferences live, and the only place their keys and defaults are spelled.
///
/// Two readers — the settings screen through `@AppStorage`, and the scheduler through
/// `current()` — so a key written in two places would be a preference the user can set and the
/// scheduler cannot see. They are named once here and both sides take them from here.
enum SessionAlertDefaults {
    static let remindBeforeStartKey   = "alerts.remindBeforeStart"
    static let startLeadMinutesKey    = "alerts.startLeadMinutes"
    static let announceSafeToWatchKey = "alerts.announceSafeToWatch"
    static let kindsKey               = "alerts.kinds"

    static let remindBeforeStart   = true
    static let startLeadMinutes    = 30
    static let announceSafeToWatch = true

    /// Practice is out of the box, everything else is in.
    ///
    /// Three hours of practice a weekend, and someone who only watches the race would be woken
    /// six times for sessions they will never open. The people who do want practice are the ones
    /// most likely to go and find the setting.
    static let kinds: Set<SessionKind> = [.qualifying, .sprintQualifying, .sprint, .race]

    /// The offered warning times, in minutes.
    static let leadChoices = [5, 15, 30, 60, 120]

    static func encode(_ kinds: Set<SessionKind>) -> String {
        kinds.map(\.rawValue).sorted().joined(separator: ",")
    }

    static func decode(_ raw: String) -> Set<SessionKind> {
        let parts = raw.split(separator: ",").map(String.init).filter { !$0.isEmpty }
        let kinds = parts.compactMap(SessionKind.init(rawValue:))
        // Dropped rather than trapped: an unreadable entry here can only come from a rawValue
        // this app used to write and no longer knows, which is a rename in our own code and not
        // something to crash a user's launch over. Logged, because silently narrowing what
        // someone asked to be told about is the kind of thing nobody reports.
        if kinds.count != parts.count {
            AppLog.alerts.error("dropped unknown session kinds from preferences",
                                ["stored": parts.count, "understood": kinds.count])
        }
        return Set(kinds)
    }

    /// What the user has currently asked for.
    ///
    /// The `??`s are reading an unset preference on a first launch, which is an expected state
    /// with a real answer, not the absent data the fail-fast rule is about.
    static func current(_ defaults: UserDefaults = .standard) -> SessionAlertPreferences {
        let wantsStart = defaults.object(forKey: remindBeforeStartKey) as? Bool ?? remindBeforeStart
        let minutes = defaults.object(forKey: startLeadMinutesKey) as? Int ?? startLeadMinutes
        let stored = defaults.string(forKey: kindsKey)

        return SessionAlertPreferences(
            startLead: wantsStart ? TimeInterval(minutes * 60) : nil,
            announceSafeToWatch: defaults.object(forKey: announceSafeToWatchKey) as? Bool
                ?? announceSafeToWatch,
            kinds: stored.map(decode) ?? kinds
        )
    }
}

/// Puts the planned alerts in front of the OS, and reports what the OS will allow.
///
/// **Deliberately thin.** Every decision worth arguing about — which alerts, when they fire, how
/// many survive the cap — is in `SessionAlertPlanner`, where it is a pure function of the
/// schedule and is covered by tests. What is left here is the part that cannot be tested without
/// a device: asking permission, and handing an array to `UNUserNotificationCenter`. Keeping that
/// boundary is what stops the untestable half growing logic of its own.
///
/// Local notifications need no entitlement — `NoSpoilersApp.entitlements` carries only the App
/// Group and does not change for this. Only remote push would.
@MainActor
final class SessionAlertScheduler: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    /// What iOS currently permits. `.notDetermined` until asked.
    @Published private(set) var authorization: UNAuthorizationStatus = .notDetermined

    /// **iOS keeps 64 pending local notifications per app and silently drops the rest.** A full
    /// season is far more than that, so the planner is given the cap and returns the soonest 64
    /// rather than letting the OS decide which to lose.
    static let pendingLimit = 64

    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    /// Show the alert even when the app is open.
    ///
    /// Without this iOS drops a foreground notification silently, which is the wrong answer for
    /// both of ours. A start warning is the one moment someone might be looking at this app —
    /// checking the time of the very session it is about to warn them about — and a safe-to-watch
    /// alert that arrives while the app is open is exactly when the user is deciding what to put
    /// on. Neither is worth swallowing; both were, until a simulator push arrived and rendered
    /// nothing at all.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func refreshAuthorization() async {
        authorization = await center.notificationSettings().authorizationStatus
    }

    /// Asks, once, and only ever from a user turning something on.
    ///
    /// The prompt is one-shot for the lifetime of the install: iOS will not show it twice, and a
    /// no is final until someone goes to Settings. Firing it on launch — before anyone knows what
    /// the app is for — is the reliable way to lose the permission permanently, so nothing here
    /// is called from app startup.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            AppLog.alerts.notice("authorization requested", ["granted": granted])
            await refreshAuthorization()
            return granted
        } catch {
            AppLog.alerts.error("authorization request failed", ["error": LogValue.error(error)])
            await refreshAuthorization()
            return false
        }
    }

    /// Replaces the pending set with what the schedule says it should be now.
    ///
    /// **Wholesale, never incremental.** A safe-to-watch alert sits at the grace-window estimate
    /// until OpenF1 publishes the real end, roughly half an hour after the fact, so a session that
    /// overran is scheduled at the wrong moment when it is first planned. Rebuilding the whole set
    /// on each launch and activation is what makes that self-correcting; topping up would preserve
    /// the first, wrong answer for as long as the alert stayed pending.
    func reschedule(weekends: [RaceWeekend], confirmedEndDates: [String: Date]) async {
        await refreshAuthorization()
        guard authorization == .authorized || authorization == .provisional else {
            // Nothing to clear: if we were never allowed to schedule, there is nothing pending.
            AppLog.alerts.notice("not scheduling", ["authorization": authorization.rawValue])
            return
        }

        let alerts = SessionAlertPlanner.plan(
            at: Date(),
            weekends: weekends,
            confirmedEndDates: confirmedEndDates,
            preferences: SessionAlertDefaults.current(),
            limit: Self.pendingLimit
        )

        center.removeAllPendingNotificationRequests()
        for alert in alerts {
            guard let request = request(for: alert) else { continue }
            do {
                try await center.add(request)
            } catch {
                AppLog.alerts.error("could not schedule alert",
                                    ["id": alert.id, "error": LogValue.error(error)])
            }
        }

        AppLog.alerts.notice("rescheduled", [
            "planned": alerts.count,
            "pending": await center.pendingNotificationRequests().count,
        ])
    }

    /// Drops everything pending. Called when the user turns the last alert off.
    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        AppLog.alerts.notice("cancelled all pending alerts")
    }

    private func request(for alert: SessionAlert) -> UNNotificationRequest? {
        let delay = alert.fireAt.timeIntervalSinceNow
        // Planned in the past between planning and here. Not an error worth a line: the plan was
        // made microseconds ago and this can only be a session on the very edge of `now`.
        guard delay > 0 else { return nil }

        let content = UNMutableNotificationContent()
        let name = alert.session.kind.displayName
        switch alert.kind {
        case .startingSoon(let lead):
            content.title = Strings.Alerts.startingSoonTitle(alert.session.grandPrixName)
            content.body = Strings.Alerts.startingSoonBody(
                session: name,
                minutes: Int((lead / 60).rounded())
            )
        case .safeToWatch:
            content.title = Strings.Alerts.safeToWatchTitle(alert.session.grandPrixName)
            content.body = Strings.Alerts.safeToWatchBody(session: name)
        }
        content.sound = .default

        // A time interval rather than calendar components, deliberately. These are absolute
        // instants — a session starts when it starts, wherever the phone is — and a calendar
        // trigger built from today's time zone would slide by an hour the moment someone flew
        // somewhere, which for this audience is a race weekend.
        return UNNotificationRequest(
            identifier: alert.id,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        )
    }
}
