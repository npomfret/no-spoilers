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
    }

    public var menuBarLabel: String {
        let now = Date()
        let pairs = weekends.sorted { $0.round < $1.round }
                            .flatMap { w in w.allSessions.map { (session: $0, weekend: w) } }
                            .sorted { $0.session.startsAt < $1.session.startsAt }
        if let live = pairs.first(where: { $0.session.startsAt <= now && now < $0.session.endsAt }) {
            return "F1 \(live.weekend.name) — now"
        }
        guard let next = pairs.first(where: { $0.session.startsAt > now }) else { return "F1" }
        let secs = Int(next.session.startsAt.timeIntervalSince(now))
        let days = secs / 86_400
        if days >= 1 { return "F1 \(next.weekend.name) in \(days) days" }
        let h = secs / 3600
        let m = (secs % 3600) / 60
        return "F1 \(next.weekend.name) in \(h > 0 ? "\(h)h" : "\(m)m")"
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
