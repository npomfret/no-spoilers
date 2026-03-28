import Foundation

/// Stateless client for the OpenF1 public REST API.
///
/// Historical data (sessions that ended >30 min ago) is free with no authentication.
/// Real-time data requires a paid subscription, which this client does not use.
struct OpenF1Client {
    private static let base = "https://api.openf1.org/v1"

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let s = try c.decode(String.self)
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fmt.date(from: s) { return date }
            fmt.formatOptions = [.withInternetDateTime]
            if let date = fmt.date(from: s) { return date }
            throw DecodingError.dataCorruptedError(
                in: c, debugDescription: "Cannot parse OpenF1 date: \(s)")
        }
        return d
    }()

    // MARK: - Public interface

    /// Returns the OpenF1 `session_key` for the given calendar session, or `nil` if the session
    /// cannot be matched (e.g. data not yet available, network error).
    func findSessionKey(for session: Session) async -> Int? {
        let year = Calendar.current.component(.year, from: session.startsAt)
        let fmt = ISO8601DateFormatter()
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        // Search ±15 min around our scheduled start to account for minor feed discrepancies.
        let lo = fmt.string(from: session.startsAt.addingTimeInterval(-15 * 60))
        let hi = fmt.string(from: session.startsAt.addingTimeInterval( 15 * 60))
        let name = session.kind.openF1SessionName
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let urlStr = "\(Self.base)/sessions"
            + "?year=\(year)"
            + "&session_name=\(name)"
            + "&date_start>=\(lo)"
            + "&date_start<=\(hi)"
        guard let url = URL(string: urlStr),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let results = try? Self.decoder.decode([OF1Session].self, from: data),
              let match = results.first
        else { return nil }
        return match.sessionKey
    }

    /// Returns the confirmed actual end time for a session, or `nil` if the
    /// `SESSION FINISHED` record is not yet available in the free historical tier
    /// (i.e. the session ended less than ~30 min ago).
    func confirmedEndDate(forSessionKey key: Int) async -> Date? {
        // Space in the message value must be percent-encoded in the URL string.
        let urlStr = "\(Self.base)/race_control"
            + "?session_key=\(key)"
            + "&category=SessionStatus"
            + "&message=SESSION%20FINISHED"
        guard let url = URL(string: urlStr),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let events = try? Self.decoder.decode([OF1RaceControl].self, from: data),
              !events.isEmpty
        else { return nil }
        // Qualifying produces one SESSION FINISHED per phase; take the latest.
        return events.map(\.date).max()
    }
}

// MARK: - Private decodable types

private struct OF1Session: Decodable {
    let sessionKey: Int
    enum CodingKeys: String, CodingKey { case sessionKey = "session_key" }
}

private struct OF1RaceControl: Decodable {
    let date: Date
}
