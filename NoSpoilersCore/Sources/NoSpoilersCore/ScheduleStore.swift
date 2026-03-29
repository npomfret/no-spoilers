import Foundation

@MainActor
public class ScheduleStore: ObservableObject {
    @Published public var weekends: [RaceWeekend] = []

    private let appGroupID: String?
    private let cache = ScheduleCache()
    private let confirmer: SessionEndConfirmer

    /// Confirmed actual end dates for sessions, keyed by `Session.id`.
    /// Populated by the OpenF1 free-tier poller once data enters the historical window.
    public var confirmedEndDates: [String: Date] { confirmer.confirmedEndDates }

    public init(appGroupID: String? = nil) {
        self.appGroupID = appGroupID
        self.confirmer = SessionEndConfirmer(appGroupID: appGroupID)
        // Eagerly load from cache so UI has data before refresh() completes.
        if let cached = try? cache.load(for: appGroupID) {
            self.weekends = cached
        }
        // Forward confirmer updates to our own objectWillChange so views re-render.
        confirmer.onChange = { [weak self] in self?.objectWillChange.send() }
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

    /// The live session if one is in progress, otherwise the next upcoming session.
    /// Returns nil when there are no live or upcoming sessions.
    public func liveOrNextSessionPair() -> (session: Session, weekend: RaceWeekend)? {
        let now = Date()
        let pairs = sortedSessionPairs()
        if let live = pairs.indices.first(where: { i in
            let next = i + 1 < pairs.count ? pairs[i + 1].session : nil
            let confirmed = confirmer.confirmedEndDates[pairs[i].session.id]
            return SessionResolver.status(for: pairs[i].session, at: now, nextSession: next, confirmedEndAt: confirmed) == .inProgress
        }).map({ pairs[$0] }) {
            precondition(!live.weekend.countryCode.isEmpty, "Live session \(live.session.id) has empty countryCode")
            return live
        }
        guard let next = pairs.first(where: { $0.session.startsAt > now }) else { return nil }
        precondition(!next.weekend.countryCode.isEmpty, "Upcoming session \(next.session.id) has empty countryCode")
        return next
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
                label = label.isEmpty ? Strings.MenuBar.live : Strings.MenuBar.liveWithSession(label)
            } else {
                let secs = Int(pair.session.startsAt.timeIntervalSince(now))
                let days = secs / 86_400
                let h = secs / 3600
                let m = (secs % 3600) / 60
                let timeStr = days >= 1 ? Strings.MenuBar.countdownDays(days)
                            : h > 0    ? Strings.MenuBar.countdownHoursMinutes(h, m)
                                       : Strings.MenuBar.countdownMinutes(m)
                label = label.isEmpty ? timeStr : Strings.MenuBar.sessionWithCountdown(label, timeStr)
            }
        }
        return label
    }

    /// Fetch → save to cache → update published state.
    /// On failure: use cache (even stale). On cache miss: blank state.
    public func refresh() async {
        do {
            let weekends = try await ScheduleFetcher().fetch()
            try? cache.save(weekends, for: appGroupID)
            self.weekends = weekends
        } catch {
            if self.weekends.isEmpty, let cached = try? cache.load(for: appGroupID) {
                self.weekends = cached
            }
            // else: keep whatever is already published (may be stale cache from init, or stay empty)
        }
        confirmer.update(weekends: self.weekends)
    }
}
