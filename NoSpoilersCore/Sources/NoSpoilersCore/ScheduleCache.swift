import Foundation

public struct ScheduleCache {
    public static let cacheTTL: TimeInterval = 86_400  // 24 hours

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

    public func isFresh(for appGroupID: String?) -> Bool {
        guard let data = try? Data(contentsOf: (try? cacheFileURL(for: appGroupID)) ?? URL(fileURLWithPath: "")) else { return false }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let envelope = try? decoder.decode(Envelope.self, from: data) else { return false }
        return Date().timeIntervalSince(envelope.cachedAt) < Self.cacheTTL
    }

    private func cacheFileURL(for appGroupID: String?) throws -> URL {
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
