import Foundation

/// The schedule as one read, for the processes that are not the app.
///
/// The weekends and the confirmed end times always travel together: every question worth asking of
/// one needs the other. `SessionResolver` cannot say whether a session is over without the
/// confirmed end, and a confirmed end with no session to attach it to is a dictionary key.
public struct ScheduleSnapshot {
    public let weekends: [RaceWeekend]
    public let confirmedEndDates: [String: Date]

    public init(weekends: [RaceWeekend], confirmedEndDates: [String: Date]) {
        self.weekends = weekends
        self.confirmedEndDates = confirmedEndDates
    }
}

/// Reads the schedule the way an extension has to: App Group cache first, network second.
///
/// **In Core because it now has two callers.** This was `resolveWidgetData` inside
/// `NoSpoilersWidget.swift`, private to the widget, for as long as the widget was the only process
/// that woke up with nothing in memory. `NextSessionIntent` is the second — Siri and Spotlight
/// launch it cold, in its own process, with the same problem and the same right answer — and a
/// copy beside the original would have been two answers to "where does the schedule come from",
/// which is the drift the core rules call a correctness issue.
///
/// `ScheduleStore` is the app's path and stays separate: it publishes, it refreshes on a timer,
/// and it belongs to a process with a lifecycle. This one is a single read that returns.
public enum ScheduleSnapshotLoader {

    /// The schedule, from wherever it can be had.
    ///
    /// Never throws. Every caller is a process that has to render *something* — a widget, an
    /// intent's answer — and the empty snapshot is a modelled state each of them already draws.
    /// This is not the missing data the fail-fast rule is about: no cache and no network is an
    /// ordinary state for a phone in a tunnel.
    public static func load(appGroupID: String? = NoSpoilersConfig.appGroupID) async -> ScheduleSnapshot {
        let cache = ScheduleCache()
        let confirmedEndDates = SessionEndConfirmer.loadStoredDates(appGroupID: appGroupID)

        let cacheResult = Result { try cache.load(for: appGroupID) }
        switch cacheResult {
        case .success(let weekends) where !weekends.isEmpty:
            AppLog.cache.notice("cache hit", ["weekends": weekends.count,
                                              "confirmedEnds": confirmedEndDates.count])
            return ScheduleSnapshot(weekends: weekends, confirmedEndDates: confirmedEndDates)
        case .success:
            AppLog.cache.notice("cache empty, falling back to network")
        case .failure(let error):
            AppLog.cache.error("cache load failed, falling back to network",
                               ["error": LogValue.error(error)])
        }

        // Cache miss or App Group unavailable — fetch directly so neither caller needs the app to
        // have run first.
        do {
            let weekends = try await ScheduleFetcher().fetch()
            AppLog.schedule.notice("network fetch", ["weekends": weekends.count])
            // Only persist a successful fetch. Writing an empty array back would overwrite a cache
            // that may be corrupt-but-recoverable with a known-bad value, and would do it precisely
            // when the network is the thing that is broken.
            do {
                try cache.save(weekends, for: appGroupID)
                AppLog.cache.notice("cache written", ["weekends": weekends.count])
            } catch {
                AppLog.cache.error("cache save failed", ["error": LogValue.error(error)])
            }
            return ScheduleSnapshot(weekends: weekends, confirmedEndDates: confirmedEndDates)
        } catch {
            // No cache and no network. Both callers model this; there is nothing to invent and
            // nothing to save.
            AppLog.schedule.error("network fetch failed", ["error": LogValue.error(error)])
            return ScheduleSnapshot(weekends: [], confirmedEndDates: confirmedEndDates)
        }
    }
}
