import Foundation
import WidgetKit

@MainActor
public class ScheduleStore: ObservableObject {
    @Published public var weekends: [RaceWeekend] = []
    @Published public private(set) var isRefreshing = false
    /// Published separately so alerts and Live Activities observe confirmation without a feed change.
    @Published public private(set) var confirmedEndDates: [String: Date] = [:]

    private let appGroupID: String?
    private let cache = ScheduleCache()
    private let confirmer: SessionEndConfirmer
    /// The refresh currently running, if any. Callers that arrive while one is in flight join it
    /// rather than starting a second fetch — three of them overlap on launch (`init`, the view's
    /// `.task`, and `scenePhase == .active`), and without this the first one to finish would clear
    /// `isRefreshing` while the others were still running, dropping the skeleton before there was
    /// anything to show.
    private var inFlightRefresh: Task<Void, Never>?

    public init(appGroupID: String? = nil) {
        self.appGroupID = appGroupID
        self.confirmer = SessionEndConfirmer(appGroupID: appGroupID)
        self.confirmedEndDates = confirmer.confirmedEndDates
        // Eagerly load from cache so UI has data before refresh() completes.
        //
        // Logged rather than `try?`-discarded, for the same reason as the save in `refresh()`:
        // this is the first state change of every launch, and "opened with an empty screen" and
        // "the App Group cache is unreadable" look identical from outside. A missing file is the
        // ordinary first-launch case and is not a failure; anything else is.
        do {
            let cached = try cache.load(for: appGroupID)
            self.weekends = cached
            AppLog.cache.notice("cache restored at launch", ["weekends": cached.count])
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            AppLog.cache.notice("no cache at launch")
        } catch {
            AppLog.cache.error("cache load failed at launch", ["error": LogValue.error(error)])
        }
        // A confirmed end changes no weekends. Publish it separately for the app's alert/activity
        // observers and ask WidgetKit to replace its cached estimated boundary.
        confirmer.onChange = { [weak self] in
            guard let self else { return }
            self.confirmedEndDates = self.confirmer.confirmedEndDates
            WidgetCenter.shared.reloadAllTimelines()
            AppLog.store.notice("widget reload requested", ["reason": "end confirmed"])
        }
        // Kick off overrun polling with whatever data we have now.
        confirmer.update(weekends: self.weekends)
        // Kick off a fetch immediately so the menu bar label is populated on
        // launch without waiting for the popover to be opened.
        Task { await refresh() }
    }

    private func sortedSessionPairs() -> [(session: Session, weekend: RaceWeekend)] {
        weekends.sorted { $0.round < $1.round }
                .flatMap { w in w.allSessions.map { (session: $0, weekend: w) } }
                .sorted { $0.session.startsAt < $1.session.startsAt }
    }

    /// The relevant scheduled or finish-unconfirmed session, otherwise the next upcoming one.
    public func liveOrNextSessionPair() -> (session: Session, weekend: RaceWeekend)? {
        guard let featured = FeaturedSessionPlanner.plan(
            at: Date(), weekends: weekends, confirmedEndDates: confirmedEndDates, lookAhead: .infinity
        ) else { return nil }
        guard let pair = sortedSessionPairs().first(where: { $0.session.id == featured.session.id }) else {
            preconditionFailure("The featured session must belong to the current schedule")
        }
        return pair
    }

    public func menuBarLabel(showSession: Bool, showCountdown: Bool) -> String {
        guard showSession || showCountdown else { return "" }
        guard let pair = liveOrNextSessionPair() else { return "" }
        let now = Date()
        let isLive = pair.session.startsAt <= now
        var label = ""
        if showSession { label = pair.session.kind.shortName }
        if showCountdown {
            if isLive {
                let status = SessionResolver.status(for: pair.session, at: now, nextSession: nil,
                                                    confirmedEndAt: confirmedEndDates[pair.session.id])
                if status == .unconfirmed {
                    label = label.isEmpty ? Strings.MenuBar.finishUnconfirmed
                        : Strings.MenuBar.sessionWithCountdown(label, Strings.MenuBar.finishUnconfirmed)
                } else {
                    label = label.isEmpty ? Strings.MenuBar.live : Strings.MenuBar.liveWithSession(label)
                }
            } else {
                // The menu bar has one line and shares it with the app icon, so this stops at
                // hours where the popover behind it goes down to seconds.
                let remaining = DurationBreakdown(until: pair.session.startsAt, from: now)
                let timeStr = remaining.days >= 1 ? Strings.MenuBar.countdownDays(remaining.days)
                            : remaining.hours > 0 ? Strings.MenuBar.countdownHoursMinutes(remaining.hours, remaining.minutes)
                                                  : Strings.MenuBar.countdownMinutes(remaining.minutes)
                label = label.isEmpty ? timeStr : Strings.MenuBar.sessionWithCountdown(label, timeStr)
            }
        }
        return label
    }

    /// Fetch → save to cache → update published state.
    /// On failure: use cache (even stale). On cache miss: blank state.
    ///
    /// Concurrent callers join the fetch already in flight instead of starting another.
    public func refresh() async {
        if let existing = inFlightRefresh {
            await existing.value
            return
        }
        let task = Task { await performRefresh() }
        inFlightRefresh = task
        await task.value
        if inFlightRefresh == task { inFlightRefresh = nil }
    }

    private func performRefresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let weekends = try await ScheduleFetcher().fetch()
            AppLog.schedule.notice("fetched", ["weekends": weekends.count])
            // Was `try? cache.save(...)`, which discarded the error. The widget reads this
            // container and nothing else, so a failing write is the exact shape of "the app
            // looks fine and the widget is a week out of date" — and it was unobservable.
            // Behaviour is unchanged: the refresh still continues.
            do {
                try cache.save(weekends, for: appGroupID)
                AppLog.cache.notice("cache written", ["weekends": weekends.count])
            } catch {
                AppLog.cache.error("cache save failed", ["error": LogValue.error(error)])
            }
            // Compare the weekends themselves, not just their round numbers. A session moved by an
            // hour, a weekend rescheduled, or a race cancelled in place all leave the round list
            // identical, and the widget would never be told.
            let changed = weekends != self.weekends
            self.weekends = weekends
            // `changed` is the whole reason the widget ever hears about a rescheduled session,
            // so a trace has to say which way it went. "The widget did not update" and "the
            // schedule did not change" are the same picture and different bugs.
            AppLog.store.notice("refresh complete", ["weekends": weekends.count,
                                                     "changed": changed])
            if changed {
                WidgetCenter.shared.reloadAllTimelines()
                AppLog.store.notice("widget reload requested", ["reason": "schedule changed"])
            }
        } catch {
            if self.weekends.isEmpty, let cached = try? cache.load(for: appGroupID) {
                self.weekends = cached
                AppLog.store.error("refresh failed, serving cache",
                                   ["error": LogValue.error(error), "weekends": cached.count])
            } else {
                // Keep whatever is already published — a stale cache from init, or nothing.
                AppLog.store.error("refresh failed, keeping published state",
                                   ["error": LogValue.error(error), "weekends": self.weekends.count])
            }
        }
        confirmer.update(weekends: self.weekends)
    }
}
