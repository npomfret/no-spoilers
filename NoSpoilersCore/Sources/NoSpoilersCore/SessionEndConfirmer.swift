import Foundation

/// Polls OpenF1 for authoritative session end times during the overrun grace window.
///
/// The free OpenF1 tier makes `SESSION FINISHED` records available approximately
/// 30 minutes after the actual session end. Once found, the confirmed end date is
/// stored in shared `UserDefaults` (via `appGroupID`) so that extension processes
/// (e.g. the widget) can read it without running a polling loop of their own.
///
/// Usage: call `update(weekends:)` whenever the schedule changes. The confirmer
/// will start (or restart) a background polling loop only while sessions are in
/// their overrun grace window and a confirmed end has not yet been found.
@MainActor
public final class SessionEndConfirmer {
    public private(set) var confirmedEndDates: [String: Date] = [:]

    /// Called on the main actor whenever a new confirmed end date is stored.
    var onChange: (() -> Void)?

    private let appGroupID: String?
    private let client = OpenF1Client()
    private var pollingTask: Task<Void, Never>?
    private var sessionKeyCache: [String: Int] = [:]  // session.id → OpenF1 session_key

    private static let storageKey = "no-spoilers.confirmedSessionEndDates"

    // MARK: - Init

    public init(appGroupID: String? = nil) {
        self.appGroupID = appGroupID
        // Restore any previously confirmed end dates from shared storage.
        if let raw = (UserDefaults(suiteName: appGroupID) ?? .standard)
            .dictionary(forKey: Self.storageKey) as? [String: Double] {
            confirmedEndDates = raw.mapValues { Date(timeIntervalSince1970: $0) }
        }
    }

    // MARK: - Public

    /// Call this whenever the weekend schedule changes (e.g. after a refresh).
    /// Starts or restarts the polling loop if any sessions are in their overrun window.
    public func update(weekends: [RaceWeekend]) {
        let sessions = weekends.flatMap(\.allSessions).sorted { $0.startsAt < $1.startsAt }
        pollingTask?.cancel()
        guard !pendingSessions(in: sessions, at: Date()).isEmpty else { return }
        pollingTask = Task { await pollLoop(sessions: sessions) }
    }

    // MARK: - Widget / extension support

    /// Loads confirmed end dates from shared `UserDefaults` without creating an instance.
    /// Intended for widget extension processes that cannot run a live polling loop.
    public nonisolated static func loadStoredDates(appGroupID: String?) -> [String: Date] {
        guard let raw = (UserDefaults(suiteName: appGroupID) ?? .standard)
            .dictionary(forKey: storageKey) as? [String: Double]
        else { return [:] }
        return raw.mapValues { Date(timeIntervalSince1970: $0) }
    }

    // MARK: - Private

    /// Sessions that are past their scheduled end, still within the grace window,
    /// and for which no confirmed end date has been found yet.
    private func pendingSessions(in sessions: [Session], at now: Date) -> [Session] {
        sessions.enumerated().compactMap { i, session in
            guard confirmedEndDates[session.id] == nil else { return nil }
            guard session.endsAt < now else { return nil }
            let next = i + 1 < sessions.count ? sessions[i + 1] : nil
            guard SessionResolver.status(for: session, at: now, nextSession: next) == .inProgress
            else { return nil }
            return session
        }
    }

    private func pollLoop(sessions: [Session]) async {
        while !Task.isCancelled {
            let now = Date()
            let pending = pendingSessions(in: sessions, at: now)
            guard !pending.isEmpty else { break }

            for session in pending {
                guard !Task.isCancelled else { return }
                await fetchAndStore(session: session)
            }

            guard !Task.isCancelled else { break }
            try? await Task.sleep(for: .seconds(120))
        }
    }

    private func fetchAndStore(session: Session) async {
        if sessionKeyCache[session.id] == nil {
            sessionKeyCache[session.id] = await client.findSessionKey(for: session)
        }
        guard let key = sessionKeyCache[session.id] else { return }
        guard let endDate = await client.confirmedEndDate(forSessionKey: key) else { return }
        confirmedEndDates[session.id] = endDate
        persist()
        onChange?()
    }

    private func persist() {
        let raw = confirmedEndDates.mapValues { $0.timeIntervalSince1970 }
        (UserDefaults(suiteName: appGroupID) ?? .standard).set(raw, forKey: Self.storageKey)
    }
}
