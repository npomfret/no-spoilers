import Foundation

/// The App Group copy of the schedule: written by the apps, read by the widget.
///
/// **There is no freshness contract here, on purpose.** This used to carry a 24-hour `cacheTTL` and
/// an `isFresh(for:)` to compare against it, and nothing ever called either — `refresh()` saves
/// unconditionally and the widget draws whatever it finds, at any age. That is the correct
/// behaviour and not an oversight: a widget that will not render without the network shows grey
/// bars, which is worse than showing yesterday's schedule. Both were removed on 2026-08-17 rather
/// than left implying a rule the app does not follow.
///
/// `cachedAt` stays in the envelope. It costs a line, it is the only record of when a cache was
/// written, and a TTL that ever did become real would need it.
public struct ScheduleCache {
    private struct Envelope: Codable {
        let cachedAt: Date
        let weekends: [RaceWeekend]
    }

    public init() {}

    public func save(_ weekends: [RaceWeekend], for appGroupID: String?) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(Envelope(cachedAt: Date(), weekends: weekends))
        try data.write(to: try cacheFileURL(for: appGroupID), options: .atomic)
    }

    public func load(for appGroupID: String?) throws -> [RaceWeekend] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try Data(contentsOf: try cacheFileURL(for: appGroupID))
        return try decoder.decode(Envelope.self, from: data).weekends
    }

    /// Not `private`, so a test can assert what is actually on disk. `cachedAt` has no reader in
    /// product code now that `isFresh` is gone, and an unread field with no assertion is one
    /// tidy-up away from being deleted as dead weight.
    func cacheFileURL(for appGroupID: String?) throws -> URL {
        let container: URL
        if let groupID = appGroupID {
            guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
                throw ScheduleCacheError.containerUnavailable
            }
            container = url
        } else {
            container = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        }
        return container.appendingPathComponent("schedule-cache.json")
    }
}

public enum ScheduleCacheError: Error {
    case containerUnavailable
}
