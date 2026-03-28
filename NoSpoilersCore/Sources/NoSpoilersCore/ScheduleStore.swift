import Foundation

@MainActor
public class ScheduleStore: ObservableObject {
    @Published public var weekends: [RaceWeekend] = []

    private let appGroupID: String?
    private let cache = ScheduleCache()

    public init(appGroupID: String? = nil) {
        self.appGroupID = appGroupID
        // Eagerly load from cache so UI has data before refresh() completes.
        if let cached = try? cache.load(for: appGroupID) {
            self.weekends = cached
        }
        // Kick off a fetch immediately so the menu bar label is populated on
        // launch without waiting for the popover to be opened.
        Task { await refresh() }
    }

    private func sortedSessionPairs() -> [(session: Session, weekend: RaceWeekend)] {
        weekends.sorted { $0.round < $1.round }
                .flatMap { w in w.allSessions.map { (session: $0, weekend: w) } }
                .sorted { $0.session.startsAt < $1.session.startsAt }
    }

    public func menuBarLabel(showFlag: Bool, showSession: Bool, showCountdown: Bool) -> String {
        guard showFlag || showSession || showCountdown else { return "" }
        let now = Date()
        let pairs = sortedSessionPairs()
        if let live = pairs.first(where: { $0.session.startsAt <= now && now < $0.session.endsAt }) {
            var label = ""
            if showFlag    { label = live.weekend.countryFlag }
            if showSession { label = label.isEmpty ? live.session.kind.shortName : "\(label) \(live.session.kind.shortName)" }
            if showCountdown { label = label.isEmpty ? "now" : "\(label) — now" }
            return label
        }
        guard let next = pairs.first(where: { $0.session.startsAt > now }) else { return "" }
        var label = ""
        if showFlag    { label = next.weekend.countryFlag }
        if showSession { label = label.isEmpty ? next.session.kind.shortName : "\(label) \(next.session.kind.shortName)" }
        if showCountdown {
            let secs = Int(next.session.startsAt.timeIntervalSince(now))
            let days = secs / 86_400
            let h = secs / 3600
            let m = (secs % 3600) / 60
            let timeStr = days >= 1 ? "in \(days)d" : (h > 0 ? "\(h)h \(m)m" : "\(m)m")
            label = label.isEmpty ? timeStr : "\(label) · \(timeStr)"
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
    }
}
