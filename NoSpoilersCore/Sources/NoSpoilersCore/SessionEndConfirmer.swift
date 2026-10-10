import Foundation

/// Polls OpenF1 for authoritative session end times, including delayed sessions past their estimate.
///
/// The free OpenF1 tier makes `SESSION FINISHED` records available approximately
/// 30 minutes after the actual session end. Once found, the confirmed end date is
/// stored in shared `UserDefaults` (via `appGroupID`) so that extension processes
/// (e.g. the widget) can read it without running a polling loop of their own.
///
/// Usage: call `update(weekends:)` whenever the schedule changes. The confirmer
/// arms the next scheduled end and retries recent unconfirmed sessions while the process runs.
/// It cannot keep an iPhone app executing while suspended.
@MainActor
public final class SessionEndConfirmer {
    /// Matches the product's 24-hour recently-finished window. A delay or a later live session
    /// blocking free API access must not stop confirmation at the grace-window estimate.
    nonisolated static let confirmationWindow: TimeInterval = 24 * 3600
    public private(set) var confirmedEndDates: [String: Date] = [:]

    /// Called on the main actor whenever a new confirmed end date is stored.
    ///
    /// **Every surface that can show the old boundary has to be reached from here.** This
    /// forwarded to `objectWillChange` and nothing more until 2026-09-09, so a confirmed end
    /// reached the app's views and never asked WidgetKit to reload: the widget went on saying
    /// *In Progress* until its next timeline entry, which the grace window bounds at 90 minutes
    /// for a race. `ScheduleStore` now reloads timelines here as well. Anything else that caches
    /// a boundary belongs in this callback too, not in a second mechanism beside it.
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
        confirmedEndDates = Self.loadStoredDates(appGroupID: appGroupID)
    }

    // MARK: - Public

    /// Call this whenever the weekend schedule changes (e.g. after a refresh).
    /// Arms future sessions as well as retrying sessions already due for confirmation.
    public func update(weekends: [RaceWeekend]) {
        let sessions = weekends.flatMap(\.allSessions).sorted { $0.startsAt < $1.startsAt }
        pollingTask?.cancel()
        pollingTask = Task { await pollLoop(sessions: sessions) }
    }

    // MARK: - Widget / extension support

    /// Loads confirmed end dates from shared `UserDefaults` without creating an instance.
    /// Intended for widget extension processes that cannot run a live polling loop.
    public nonisolated static func loadStoredDates(appGroupID: String?) -> [String: Date] {
        (UserDefaults(suiteName: appGroupID) ?? .standard).sessionDates(forKey: storageKey)
    }

    // MARK: - Private

    nonisolated static func pendingSessions(
        in sessions: [Session], at now: Date, confirmedEndDates: [String: Date]
    ) -> [Session] {
        sessions.filter { session in
            if let confirmed = confirmedEndDates[session.id], confirmed >= session.startsAt { return false }
            return session.endsAt <= now
                && now.timeIntervalSince(session.endsAt) < confirmationWindow
        }
    }

    nonisolated static func nextScheduledEnd(in sessions: [Session], after now: Date) -> Date? {
        sessions.map(\.endsAt).filter { $0 > now }.min()
    }

    private func pollLoop(sessions: [Session]) async {
        while !Task.isCancelled {
            let now = Date()
            let pending = Self.pendingSessions(in: sessions, at: now, confirmedEndDates: confirmedEndDates)
            if pending.isEmpty {
                // Arm the next scheduled end even when the app refreshed before the session.
                // Previously update() returned early, leaving no poller until another refresh.
                guard let nextEnd = Self.nextScheduledEnd(in: sessions, after: now) else { break }
                do {
                    try await Task.sleep(for: .seconds(nextEnd.timeIntervalSince(now)))
                } catch { return } // Cancellation ends this schedule's loop.
                continue
            }

            for session in pending {
                guard !Task.isCancelled else { return }
                await fetchAndStore(session: session)
            }

            guard !Task.isCancelled else { break }
            try? await Task.sleep(for: .seconds(120))
        }
    }

    private func fetchAndStore(session: Session) async {
        do {
            if sessionKeyCache[session.id] == nil {
                sessionKeyCache[session.id] = try await client.findSessionKey(for: session)
            }
            // Both `return`s below are ordinary — OpenF1 has nothing yet for a session that has
            // only just stopped running — and the loop simply comes back in two minutes.
            // `.debug`, because during an overrun this runs every 120 seconds per pending
            // session. What used to arrive here as the same `nil` and now does not is a lookup
            // that failed outright; that lands in the `catch`.
            guard let key = sessionKeyCache[session.id] else {
                AppLog.sessionEnd.debug("no session key yet", ["session": session])
                return
            }
            guard let endDate = try await client.confirmedEndDate(forSessionKey: key) else {
                AppLog.sessionEnd.debug("no confirmed end yet", ["session": session, "key": key])
                return
            }
            guard !Task.isCancelled else { return }
            guard endDate >= session.startsAt, endDate <= Date() else {
                throw OpenF1Error.invalidEndDate(endDate)
            }
            confirmedEndDates[session.id] = endDate
            persist()
            // `.notice`: this is the moment a session stops being "in progress" ahead of its
            // grace window, which changes what every view and the widget timeline show.
            AppLog.sessionEnd.notice("end confirmed", ["session": session, "endedAt": endDate])
            onChange?()
        } catch HTTPStatusError.unsuccessful(401) {
            // OpenF1 refuses every unauthenticated query, past sessions included, while any
            // session is live (observed 2026-10-10). Expected for hours at a time now that a
            // finish is retried for 24 hours, so it is not an `.error` every two minutes.
            AppLog.sessionEnd.debug("lookup refused during a live session", ["session": session])
        } catch {
            // The line this feature never had. The poller retries either way — a transient
            // OpenF1 outage should not abandon a session that is about to be confirmed — but
            // "retrying because there is nothing to find yet" and "retrying because every call
            // is failing" are now different lines, and only one of them is at `.error`.
            AppLog.sessionEnd.error("lookup failed",
                                    ["session": session, "error": LogValue.error(error)])
        }
    }

    private func persist() {
        (UserDefaults(suiteName: appGroupID) ?? .standard)
            .setSessionDates(confirmedEndDates, forKey: Self.storageKey)
    }
}
