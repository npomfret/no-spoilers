import Foundation

/// Direct Codable mapping of one race object from the f1calendar feed.
///
/// Feed shape:
/// ```json
/// {
///   "round": 1, "name": "Australian", "location": "Melbourne",
///   "sessions": { "fp1": "2026-03-13T01:30:00Z", "gp": "2026-03-15T05:00:00Z", ... }
/// }
/// ```
public struct RaceWeekend: Codable, Identifiable, Hashable {
    public let round: Int
    public let name: String        // short form from feed: "Australian"
    public let location: String
    public let sessions: [SessionKind: Date]

    public var id: Int { round }
    public var grandPrixName: String { "\(name) Grand Prix" }
    public var countryFlag: String {
        switch name {
        case "Australian":          return "🇦🇺"
        case "Chinese":             return "🇨🇳"
        case "Japanese":            return "🇯🇵"
        case "Miami":               return "🇺🇸"
        case "Canadian":            return "🇨🇦"
        case "Monaco":              return "🇲🇨"
        case "Barcelona-Catalunya": return "🇪🇸"
        case "Austrian":            return "🇦🇹"
        case "British":             return "🇬🇧"
        case "Belgian":             return "🇧🇪"
        case "Hungarian":           return "🇭🇺"
        case "Dutch":               return "🇳🇱"
        case "Italian":             return "🇮🇹"
        case "Spanish":             return "🇪🇸"
        case "Azerbaijan":          return "🇦🇿"
        case "Singapore":           return "🇸🇬"
        case "United States":       return "🇺🇸"
        case "Mexican":             return "🇲🇽"
        case "Brazilian":           return "🇧🇷"
        case "Las Vegas":           return "🇺🇸"
        case "Qatar":               return "🇶🇦"
        case "Abu Dhabi":           return "🇦🇪"
        default:                    return "🏁"
        }
    }

    enum CodingKeys: String, CodingKey {
        case round, name, location, sessions
    }

    public init(round: Int, name: String, location: String, sessions: [SessionKind: Date]) {
        self.round    = round
        self.name     = name
        self.location = location
        self.sessions = sessions
    }

    public init(from decoder: Decoder) throws {
        let c    = try decoder.container(keyedBy: CodingKeys.self)
        round    = try c.decode(Int.self,    forKey: .round)
        name     = try c.decode(String.self, forKey: .name)
        location = try c.decode(String.self, forKey: .location)
        let raw  = try c.decode([String: Date].self, forKey: .sessions)
        sessions = Dictionary(uniqueKeysWithValues: raw.compactMap { key, date in
            SessionKind(rawValue: key).map { ($0, date) }
        })
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(round,    forKey: .round)
        try c.encode(name,     forKey: .name)
        try c.encode(location, forKey: .location)
        try c.encode(
            Dictionary(uniqueKeysWithValues: sessions.map { ($0.key.rawValue, $0.value) }),
            forKey: .sessions
        )
    }
}

public extension RaceWeekend {
    /// Flat, chronologically sorted list of all sessions in this weekend.
    var allSessions: [Session] {
        sessions
            .map { Session(round: round, grandPrixName: grandPrixName, location: location, kind: $0.key, startsAt: $0.value) }
            .sorted { $0.startsAt < $1.startsAt }
    }
}
