import Foundation

/// Fetches the current season's schedule from the f1calendar feed.
///
/// The season year comes from the feed's own `config.json` (`calendarOutputYear`), not from a
/// hardcoded constant and not from the clock.
///
/// It used to be hardcoded — `2026.json`, in two places and derived nowhere — which meant that at
/// the rollover every surface would show a permanently finished season, with no error state, and
/// rendered identically to the intentional off-season view. Deriving the year from the clock
/// instead would move to the new season on 1 January whether or not that calendar file exists
/// yet. `calendarOutputYear` is maintained by the same people who publish the calendar files, so
/// it changes when the data does, which is the only signal that is actually about the data.
///
/// This is the single place either the URL or the year is decided. The widget calls it too.
public actor ScheduleFetcher {
    private static let feedRoot = URL(string: "https://raw.githubusercontent.com/sportstimes/f1/main/_db/f1/")!

    /// Ephemeral rather than `URLSession.shared`: this runs inside the widget extension as well as
    /// the apps, and Apple advises against `.shared` in extension contexts. Losing the URL cache
    /// costs nothing — `ScheduleCache` is the caching layer.
    ///
    /// Timeouts are short and explicit. The widget's own fetch used to bound itself at 8 seconds
    /// and that bound has to survive here, because a widget stuck waiting on a hung request shows
    /// the redacted placeholder — grey bars — for as long as it waits. See task 19.
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 20
        return URLSession(configuration: configuration)
    }()

    public init() {}

    public func fetch() async throws -> [RaceWeekend] {
        let year = try await currentSeasonYear()
        let (data, _) = try await session.data(from: Self.feedRoot.appending(path: "\(year).json"))
        let response = try decoder().decode(FeedResponse.self, from: data)
        return response.races.sorted { $0.round < $1.round }
    }

    /// The season the feed is currently publishing.
    ///
    /// Throws rather than guessing if the config cannot be read. `ScheduleStore.refresh()` falls
    /// back to its cache on a throw, which is the right answer for a transient network failure and
    /// far better than silently fetching a season that may not be the current one.
    private func currentSeasonYear() async throws -> Int {
        let (data, _) = try await session.data(from: Self.feedRoot.appending(path: "config.json"))
        return try decoder().decode(FeedConfig.self, from: data).calendarOutputYear
    }

    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private struct FeedResponse: Codable {
    let races: [RaceWeekend]
}

/// Only the field we need. The feed's config carries site settings we have no use for.
private struct FeedConfig: Codable {
    let calendarOutputYear: Int
}
