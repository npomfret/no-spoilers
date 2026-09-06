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
/// This is the single place the year is decided. The URL is `NoSpoilersConfig.feedRoot`, which
/// is where a launch environment can redirect it at a fixture; this actor does not know whether
/// it has been. The widget calls it too.
public actor ScheduleFetcher {
    private static let feedRoot = NoSpoilersConfig.feedRoot

    /// The session this type used to configure privately now belongs to every fetch site — see
    /// `HTTPSession`, which carries the ephemeral-not-`.shared` reasoning and the widget's
    /// eight-second bound. It is a `static let` there, so a fresh `ScheduleFetcher` per refresh no
    /// longer means a fresh `URLSession` per refresh.
    public init() {}

    public func fetch() async throws -> [RaceWeekend] {
        if NoSpoilersConfig.feedRootIsOverridden {
            // `.notice`, on every fetch: a picture of a fixture must never pass for the calendar,
            // and this line beside `refresh complete` is what says which one it was.
            AppLog.schedule.notice("feed redirected", ["root": Self.feedRoot.absoluteString])
        }
        let year = try await currentSeasonYear()
        let (data, response) = try await HTTPSession.shared.data(from: Self.feedRoot.appending(path: "\(year).json"))
        // The feed is served by GitHub's raw host, which answers an outage or a rate limit with a
        // status and an HTML body. Decoding that body reports a schema change, which sends the
        // next person reading the trace to the wrong place entirely. See `requireSuccess`.
        try response.requireSuccess()
        let feed = try decoder().decode(FeedResponse.self, from: data)
        return feed.races.sorted { $0.round < $1.round }
    }

    /// The season the feed is currently publishing.
    ///
    /// Throws rather than guessing if the config cannot be read. `ScheduleStore.refresh()` falls
    /// back to its cache on a throw, which is the right answer for a transient network failure and
    /// far better than silently fetching a season that may not be the current one.
    private func currentSeasonYear() async throws -> Int {
        let (data, response) = try await HTTPSession.shared.data(from: Self.feedRoot.appending(path: "config.json"))
        try response.requireSuccess()
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
