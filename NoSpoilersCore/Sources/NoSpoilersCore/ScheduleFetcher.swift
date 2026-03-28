import Foundation

actor ScheduleFetcher {
    private static let feedURL = URL(string: "https://raw.githubusercontent.com/sportstimes/f1/main/_db/f1/2026.json")!

    func fetch() async throws -> [RaceWeekend] {
        let (data, _) = try await URLSession.shared.data(from: Self.feedURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(FeedResponse.self, from: data)
        return response.races.sorted { $0.round < $1.round }
    }
}

private struct FeedResponse: Codable {
    let races: [RaceWeekend]
}
