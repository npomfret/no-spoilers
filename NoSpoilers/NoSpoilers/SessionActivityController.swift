import ActivityKit
import Combine
import Foundation
import NoSpoilersCore

/// Puts the planned Live Activity in front of ActivityKit, and takes it away again.
///
/// **Deliberately thin, for the same reason `SessionAlertScheduler` is.** Every decision worth
/// arguing about — which session, which phase, when it is over — is in `FeaturedSessionPlanner`,
/// where it is a pure function of the schedule and is covered by tests. What is left here is the
/// part no test can reach: asking ActivityKit to start, update or end something. Keeping that
/// boundary is what stops the untestable half growing logic of its own.
///
/// **Live Activities need no authorization prompt and no entitlement.** `areActivitiesEnabled` is
/// a Settings switch the user may already have turned off, which is not the same as being asked;
/// there is nothing to request and nothing to spend, so unlike the notification permission this
/// can be consulted freely. `NoSpoilersApp.entitlements` carries only the App Group and does not
/// change — only push-to-start would need more, and that needs a server this product does not
/// have.
///
/// **Started only from the foreground.** ActivityKit permits `request` nowhere else without push,
/// so the shape of the feature is "open the app, and the countdown moves to your Lock Screen".
/// Every call site is a foreground moment `ContentView` already owns.
///
/// `ObservableObject` with nothing published, and owned by `NoSpoilersApp` for the same reason
/// `SessionAlertScheduler` is: it must survive the view being rebuilt. There is no state to
/// publish because ActivityKit holds it — `Activity.activities` is the record, and it is read back
/// on every refresh rather than mirrored here, where a second copy could disagree with the Lock
/// Screen.
@MainActor
final class SessionActivityController: ObservableObject {

    /// How far ahead a session may start and still be worth an activity.
    ///
    /// **An activity runs 8 hours active** and stays visible up to 4 more in a stale state, so a
    /// countdown started earlier than this would be ended by the system before the session it is
    /// counting to. That is ActivityKit's budget rather than a domain fact, which is why the
    /// planner takes it as a parameter and it is spelled here — the same split that puts the
    /// widget's `maxEntries` in the widget and the 64-notification cap in the scheduler.
    static let lookAhead: TimeInterval = 8 * 3600

    /// Brings what is on the Lock Screen into line with what the schedule now says.
    ///
    /// **Replaced wholesale rather than topped up**, exactly as the pending notification set is,
    /// and for the same reason: an activity's end is the grace-window estimate until OpenF1
    /// publishes the real one, so it is placed at the wrong instant when it is first started and
    /// at the right one after the next refresh. Recomputing on every foreground is what makes that
    /// self-correcting.
    func refresh(weekends: [RaceWeekend], confirmedEndDates: [String: Date]) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            // Nothing to clear: with the switch off there is nothing of ours running.
            AppLog.activity.notice("live activities are turned off")
            return
        }

        let plan = FeaturedSessionPlanner.plan(
            at: Date(),
            weekends: weekends,
            confirmedEndDates: confirmedEndDates,
            lookAhead: Self.lookAhead
        )

        guard let plan else {
            await endAll(reason: "nothing within the look-ahead")
            return
        }

        let attributes = plan.activityAttributes
        let content = ActivityContent(
            state: plan.activityContentState,
            staleDate: plan.activityContentState.staleDate
        )

        // At most one of ours ever runs. Anything whose session is not the planned one is a
        // countdown to a moment that has passed, and ending it is the only way it goes away —
        // the system keeps a stale activity on screen for hours rather than removing it.
        var matched = false
        for activity in Activity<SessionActivityAttributes>.activities {
            if activity.attributes == attributes && !matched {
                matched = true
                await activity.update(content)
                AppLog.activity.notice("updated", [
                    "session": plan.session.id,
                    "phase": String(describing: plan.phase),
                ])
            } else {
                await activity.end(nil, dismissalPolicy: .immediate)
                AppLog.activity.notice("ended a superseded activity",
                                       ["round": activity.attributes.round])
            }
        }

        guard !matched else { return }

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                // No push type: there is no server, so every change to this activity is made by
                // the app while it is open.
                pushType: nil
            )
            AppLog.activity.notice("started", [
                "session": plan.session.id,
                "phase": String(describing: plan.phase),
                "id": activity.id,
            ])
        } catch {
            // Reachable in normal use rather than only on a bug: iOS caps how many activities one
            // app may run and refuses while the device is in some states, and a refusal here is
            // invisible to the user — the Lock Screen simply stays as it was.
            AppLog.activity.error("could not start", ["error": LogValue.error(error)])
        }
    }

    /// Takes down anything of ours that is still running.
    func endAll(reason: StaticString) async {
        let running = Activity<SessionActivityAttributes>.activities
        guard !running.isEmpty else { return }
        for activity in running {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        AppLog.activity.notice(reason, ["ended": running.count])
    }
}
