import Foundation

/// Stateless client for the OpenF1 public REST API.
///
/// Historical data (sessions that ended >30 min ago) is free with no authentication.
/// Real-time data requires a paid subscription, which this client does not use.
///
/// ## Why these methods throw *and* return an optional
///
/// There are two entirely different "no answer" here and the caller has to tell them apart.
///
/// - **`nil` — the query worked and OpenF1 has nothing yet.** Completely ordinary: the free tier
///   publishes `SESSION FINISHED` roughly 30 minutes late, which is the whole reason
///   `SessionEndConfirmer` polls at all. Nothing is wrong and nothing needs saying loudly.
/// - **A throw — the query did not work.** Network down, non-2xx status, schema changed.
///
/// Both used to be the same `nil`, produced by a `guard` chain of four `try?`s that also
/// discarded the `URLResponse`. The poller reacts to `nil` by coming back in two minutes, so a
/// dead OpenF1 and a session that finished ninety seconds ago were the same silent retry,
/// forever. Distinguishing them is the entire point of this shape.
///
/// This is `throws` rather than a `Result` or a bespoke enum because `throws` is how every other
/// failure in this package is already spelled — `ScheduleFetcher.fetch()`, `ScheduleCache.load`,
/// `ScheduleCache.save` — and one error style per package is worth more than a marginally
/// prettier call site.
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

    /// Returns the OpenF1 `session_key` for the given calendar session, or `nil` if OpenF1 has no
    /// matching session — which for a session that has only just started is the normal answer.
    ///
    /// Throws if the lookup could not be made: see the note on the type.
    func findSessionKey(for session: Session) async throws -> Int? {
        let results: [OF1Session] = try await get(Self.sessionsURL(for: session))
        return results.first?.sessionKey
    }

    /// Returns the confirmed actual end time for a session, or `nil` if the `SESSION FINISHED`
    /// record is not yet in the free historical tier (i.e. it ended less than ~30 min ago).
    ///
    /// Throws if the lookup could not be made: see the note on the type.
    func confirmedEndDate(forSessionKey key: Int) async throws -> Date? {
        let events: [OF1RaceControl] = try await get(Self.sessionFinishedURL(forSessionKey: key))
        // Qualifying produces one SESSION FINISHED per phase; take the latest.
        return events.map(\.date).max()
    }

    // MARK: - URLs
    //
    // Built as strings and exposed to tests, rather than assembled inline where nothing could see
    // them. OpenF1 filters by putting the comparison into the query *name* — `date_start>=...` —
    // which `URLComponents` cannot express, so these are assembled by hand and **written already
    // percent-encoded**, `%3E` and `%3C` included.
    //
    // That is not decoration. `URL(string:)` runs an encoding fixup over any string that is not
    // already a valid URL, and a bare `>` makes it not valid — so the fixup ran, and it re-encoded
    // the `%` of an already-encoded space into `%25`. Every multi-word session name went out as
    // `Practice%25201`, which OpenF1 answers with "no results", which this client reported as "not
    // published yet". **Session-end confirmation had never once worked for FP1, FP2, FP3 or Sprint
    // Qualifying**, and could not: the failure was identical to the ordinary answer. Race, Sprint
    // and Qualifying worked only because their names have no space in them.
    //
    // Writing the encoding out in full means the fixup has nothing to do, which `url(_:)` then
    // enforces outright.

    static func sessionsURL(for session: Session) throws -> URL {
        let year = Calendar.current.component(.year, from: session.startsAt)
        let fmt = ISO8601DateFormatter()
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        // Search ±15 min around our scheduled start to account for minor feed discrepancies.
        let lo = fmt.string(from: session.startsAt.addingTimeInterval(-15 * 60))
        let hi = fmt.string(from: session.startsAt.addingTimeInterval( 15 * 60))
        // Was `?? ""`, a sentinel that would have asked OpenF1 for every session of the year
        // named nothing at all, and reported the empty result as "not published yet".
        guard let name = session.kind.openF1SessionName
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else {
            throw OpenF1Error.unencodableSessionName(session.kind.openF1SessionName)
        }

        return try url("\(base)/sessions"
            + "?year=\(year)"
            + "&session_name=\(name)"
            + "&date_start%3E=\(lo)"
            + "&date_start%3C=\(hi)")
    }

    static func sessionFinishedURL(forSessionKey key: Int) throws -> URL {
        try url("\(base)/race_control"
            + "?session_key=\(key)"
            + "&category=SessionStatus"
            + "&message=SESSION%20FINISHED")
    }

    /// Refuses a URL that Foundation would rewrite on the way through.
    ///
    /// The equality check is the guard against the double-encoding above ever returning. Anything
    /// `URL(string:)` alters is a query we did not write and cannot reason about — and because
    /// OpenF1 answers a malformed query the same way it answers an empty one, sending it would
    /// fail invisibly. Refusing loudly is the only version of this that can be noticed.
    /// Not `private`, so `OpenF1URLTests` can hand it the string that caused the bug. The two
    /// builders above cannot produce one any more, which is exactly why the guard needs its own
    /// test rather than an indirect one.
    static func url(_ string: String) throws -> URL {
        guard let url = URL(string: string), url.absoluteString == string else {
            throw OpenF1Error.malformedURL(string)
        }
        return url
    }

    // MARK: - Private

    private func get<T: Decodable>(_ url: URL) async throws -> [T] {
        let (data, response) = try await HTTPSession.shared.data(from: url)
        // **OpenF1 answers an empty result set with 404 and `{"detail":"No results found."}`**,
        // not with 200 and `[]`. Verified against the live API on 2026-08-17. That is the ordinary
        // answer for a session whose record is not published yet — it is what every poll gets for
        // the first ~30 minutes — so it is emptiness and not a failure, and putting it through
        // `requireSuccess` would log the most routine case in the feature at `.error`.
        //
        // A mistyped path would also 404 and would also read as empty. `OpenF1URLTests` is what
        // covers that instead, at build time, where it can actually be told apart.
        if let http = response as? HTTPURLResponse, http.statusCode == 404 { return [] }
        try response.requireSuccess()
        return try Self.decoder.decode([T].self, from: data)
    }
}

enum OpenF1Error: Error, Equatable {
    /// Foundation would have rewritten this URL. See `url(_:)`.
    case malformedURL(String)
    case unencodableSessionName(String)
}

// MARK: - Private decodable types

private struct OF1Session: Decodable {
    let sessionKey: Int
    enum CodingKeys: String, CodingKey { case sessionKey = "session_key" }
}

private struct OF1RaceControl: Decodable {
    let date: Date
}
