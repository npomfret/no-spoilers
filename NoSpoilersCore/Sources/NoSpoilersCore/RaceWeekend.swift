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
    public var grandPrixName: String { Strings.RaceNames.grandPrix(name) }
    public var countryName: String { Strings.CountryNames.name(for: name) }
    /// ISO country code for the flag asset, or nil when the feed names a Grand Prix in a way this
    /// mapping does not cover.
    ///
    /// Nil is a real state, not a placeholder. The 2026 feed carries round 16 as
    /// "Bahrain Grand Prix (Malaysia)" at Sepang, which matches nothing here. This used to return
    /// `""` and `ScheduleStore` used to `precondition` on the result being non-empty, so the
    /// combination was a scheduled crash: the menu bar app would have died the moment that round
    /// became the next session. A country we cannot identify is possible data — the feed is not
    /// ours and its naming changes — so it is modelled, not asserted away. `FlagImage` renders a
    /// chequered flag for nil, which is the honest answer.
    public var countryCode: String? {
        switch name {
        case "Australian":          return "AU"
        case "Chinese":             return "CN"
        case "Japanese":            return "JP"
        case "Miami":               return "US"
        case "Canadian":            return "CA"
        case "Monaco":              return "MC"
        case "Barcelona-Catalunya": return "ES"
        case "Austrian":            return "AT"
        case "British":             return "GB"
        case "Belgian":             return "BE"
        case "Hungarian":           return "HU"
        case "Dutch":               return "NL"
        case "Italian":             return "IT"
        case "Spanish":             return "ES"
        case "Azerbaijan":          return "AZ"
        case "Singapore":           return "SG"
        case "United States":       return "US"
        case "Mexican":             return "MX"
        case "Brazilian":           return "BR"
        case "Las Vegas":           return "US"
        case "Qatar":               return "QA"
        case "Abu Dhabi":           return "AE"
        default:                    return nil
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
