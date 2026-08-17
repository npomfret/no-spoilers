import WidgetKit
import SwiftUI
import NoSpoilersCore

private let widgetRed = BrandPalette.signalRed


// MARK: - Entry

struct NoSpoilersEntry: TimelineEntry {
    let date: Date
    let weekend: RaceWeekend?
    let sessions: [SessionViewModel]
    let nextWeekend: UpcomingWeekendViewModel?
    /// True only when the loaded schedule is exhausted — no upcoming sessions at all.
    let isOffSeason: Bool
}

// MARK: - View Models

struct SessionViewModel: Identifiable {
    let id: String
    let name: String
    let shortName: String
    let state: SessionState
}

struct UpcomingWeekendViewModel {
    let round: Int
    let countryCode: String?
    let name: String
    let location: String
    let startsAt: Date
}

enum SessionState {
    case finished(at: Date)
    case live
    case upcoming(startsAt: Date)
}

// MARK: - Helpers

/// Thin wrapper over the shared resolver, purely to keep the `[String: Date]` lookup off every
/// call site here. The logic itself now lives in `SessionResolver` — this was the only correct
/// implementation of it, and both apps were using `session.endsAt` instead.
private func effectiveSessionEndDate(
    for session: Session,
    nextSession: Session?,
    confirmedEndDates: [String: Date]
) -> Date {
    SessionResolver.effectiveEndDate(
        for: session,
        nextSession: nextSession,
        confirmedEndAt: confirmedEndDates[session.id]
    )
}

private func sessionState(for session: Session, nextSession: Session?, at now: Date, confirmedEndDates: [String: Date]) -> SessionState {
    switch SessionResolver.status(for: session, at: now, nextSession: nextSession, confirmedEndAt: confirmedEndDates[session.id]) {
    case .finished:
        return .finished(at: effectiveSessionEndDate(for: session, nextSession: nextSession, confirmedEndDates: confirmedEndDates))
    case .inProgress:
        return .live
    case .upcoming:
        return .upcoming(startsAt: session.startsAt)
    }
}

private struct WidgetDataSnapshot {
    let weekends: [RaceWeekend]
    let confirmedEndDates: [String: Date]
}

/// Reads weekends from the shared cache; if the cache is empty or inaccessible, fetches from the
/// network and writes back to cache so the next reload is fast.
///
/// The fetch goes through `ScheduleFetcher` like everything else. This used to be a second
/// implementation — its own `Codable` response type, its own hardcoded feed URL, and a
/// `DispatchSemaphore` to make an async API synchronous. `getTimeline` takes a completion handler,
/// so there was never a need to block: it can just await.
private func resolveWidgetData() async -> WidgetDataSnapshot {
    let cache = ScheduleCache()
    let confirmedEndDates = SessionEndConfirmer.loadStoredDates(appGroupID: NoSpoilersConfig.appGroupID)

    let cacheResult = Result { try cache.load(for: NoSpoilersConfig.appGroupID) }
    switch cacheResult {
    case .success(let weekends) where !weekends.isEmpty:
        AppLog.cache.notice("cache hit", ["weekends": weekends.count,
                                          "confirmedEnds": confirmedEndDates.count])
        return WidgetDataSnapshot(weekends: weekends, confirmedEndDates: confirmedEndDates)
    case .success:
        AppLog.cache.notice("cache empty, falling back to network")
    case .failure(let error):
        AppLog.cache.error("cache load failed, falling back to network",
                           ["error": LogValue.error(error)])
    }

    // Cache miss or App Group unavailable — fetch directly so the widget does not need the app to
    // have run first.
    do {
        let weekends = try await ScheduleFetcher().fetch()
        AppLog.schedule.notice("network fetch", ["weekends": weekends.count])
        // Only persist a successful fetch. Writing an empty array back would overwrite a cache
        // that may be corrupt-but-recoverable with a known-bad value, and would do it precisely
        // when the network is the thing that is broken.
        do {
            try cache.save(weekends, for: NoSpoilersConfig.appGroupID)
            AppLog.cache.notice("cache written", ["weekends": weekends.count])
        } catch {
            AppLog.cache.error("cache save failed", ["error": LogValue.error(error)])
        }
        return WidgetDataSnapshot(weekends: weekends, confirmedEndDates: confirmedEndDates)
    } catch {
        // No cache and no network. `noDataView` is the modelled state for this; there is nothing
        // to invent and nothing to save.
        AppLog.schedule.error("network fetch failed", ["error": LogValue.error(error)])
        return WidgetDataSnapshot(weekends: [], confirmedEndDates: confirmedEndDates)
    }
}

private func placeholderEntry(at now: Date = Date()) -> NoSpoilersEntry {
    let placeholderWeekend = RaceWeekend(
        round: 16,
        name: "Japanese",
        location: "Suzuka",
        sessions: [
            .freePractice1: now.addingTimeInterval(-4 * 3600),
            .freePractice2: now.addingTimeInterval(2 * 3600),
            .freePractice3: now.addingTimeInterval(20 * 3600),
            .qualifying: now.addingTimeInterval(29 * 3600),
            .race: now.addingTimeInterval(52 * 3600)
        ]
    )

    return NoSpoilersEntry(
        date: now,
        weekend: placeholderWeekend,
        sessions: [
            SessionViewModel(id: "placeholder-fp1", name: SessionKind.freePractice1.displayName, shortName: SessionKind.freePractice1.shortName, state: .finished(at: now.addingTimeInterval(-42 * 60))),
            SessionViewModel(id: "placeholder-fp2", name: SessionKind.freePractice2.displayName, shortName: SessionKind.freePractice2.shortName, state: .upcoming(startsAt: now.addingTimeInterval(2 * 3600 + 15 * 60))),
            SessionViewModel(id: "placeholder-fp3", name: SessionKind.freePractice3.displayName, shortName: SessionKind.freePractice3.shortName, state: .upcoming(startsAt: now.addingTimeInterval(20 * 3600))),
            SessionViewModel(id: "placeholder-quali", name: SessionKind.qualifying.displayName, shortName: SessionKind.qualifying.shortName, state: .upcoming(startsAt: now.addingTimeInterval(29 * 3600))),
            SessionViewModel(id: "placeholder-race", name: SessionKind.race.displayName, shortName: SessionKind.race.shortName, state: .upcoming(startsAt: now.addingTimeInterval(52 * 3600)))
        ],
        nextWeekend: UpcomingWeekendViewModel(
            round: 17,
            countryCode: "QA",
            name: "Qatar Grand Prix",
            location: "Lusail",
            startsAt: now.addingTimeInterval(7 * 86_400)
        ),
        isOffSeason: false
    )
}

private func makeEntry(at now: Date, data: WidgetDataSnapshot) -> NoSpoilersEntry {
    let weekends = data.weekends
    let confirmedEndDates = data.confirmedEndDates

    let sortedWeekends = weekends.sorted { $0.round < $1.round }

    // Within 24h of the most recently finished weekend, keep showing it.
    if let previous = sortedWeekends.last(where: {
        !$0.allSessions.isEmpty &&
        RaceWeekendResolver.firstNonFinishedSession(in: $0, at: now, confirmedEndDates: confirmedEndDates) == nil
    }) {
        let endTime = RaceWeekendResolver.effectiveEndDate(of: previous, confirmedEndDates: confirmedEndDates)
        if now.timeIntervalSince(endTime) < 24 * 3600 {
            let prevSessions = previous.allSessions
            let sessionVMs = prevSessions.indices.map { i -> SessionViewModel in
                let s = prevSessions[i]
                let next = i + 1 < prevSessions.count ? prevSessions[i + 1] : nil
                return SessionViewModel(id: s.id, name: s.kind.displayName, shortName: s.kind.shortName,
                                        state: sessionState(for: s, nextSession: next, at: now, confirmedEndDates: confirmedEndDates))
            }
            let upcoming = RaceWeekendResolver.firstActiveWeekend(in: weekends, at: now, confirmedEndDates: confirmedEndDates)
            let nextWeekend = upcoming.flatMap { w -> UpcomingWeekendViewModel? in
                guard let first = w.allSessions.first else { return nil }
                return UpcomingWeekendViewModel(round: w.round, countryCode: w.countryCode, name: w.grandPrixName, location: w.location, startsAt: first.startsAt)
            }
            return NoSpoilersEntry(date: now, weekend: previous, sessions: sessionVMs, nextWeekend: nextWeekend, isOffSeason: false)
        }
    }

    // Show the next upcoming weekend — no distance threshold.
    guard let upcoming = RaceWeekendResolver.firstActiveWeekend(in: weekends, at: now, confirmedEndDates: confirmedEndDates) else {
        // Schedule exhausted: genuine off-season if we have data, no-data view otherwise.
        return NoSpoilersEntry(date: now, weekend: nil, sessions: [], nextWeekend: nil, isOffSeason: !weekends.isEmpty)
    }

    let sorted = upcoming.allSessions
    let sessionVMs = sorted.indices.map { i -> SessionViewModel in
        let s = sorted[i]
        let next = i + 1 < sorted.count ? sorted[i + 1] : nil
        return SessionViewModel(id: s.id, name: s.kind.displayName, shortName: s.kind.shortName,
                                state: sessionState(for: s, nextSession: next, at: now, confirmedEndDates: confirmedEndDates))
    }
    let nextWeekend = RaceWeekendResolver.nextWeekend(after: upcoming, in: weekends).flatMap { w -> UpcomingWeekendViewModel? in
        guard let first = w.allSessions.first else { return nil }
        return UpcomingWeekendViewModel(round: w.round, countryCode: w.countryCode, name: w.grandPrixName, location: w.location, startsAt: first.startsAt)
    }
    return NoSpoilersEntry(date: now, weekend: upcoming, sessions: sessionVMs, nextWeekend: nextWeekend, isOffSeason: false)
}

/// How far ahead a timeline is built.
///
/// The widget only ever displays the current or next weekend, so an entry for a boundary in
/// October is an archived SwiftUI view nobody will ever look at. Building the whole season cost
/// ~130 entries and 3-6 seconds, which is longer than SpringBoard waits before giving up and
/// leaving the redacted placeholder — grey bars — on screen.
///
/// A duration rather than an entry count, deliberately: the horizon is also the reload interval,
/// so bounding it in time bounds staleness directly and predictably. A count would leave the
/// reload date dependent on how densely the feed happens to be packed at that moment — dense
/// during a race weekend, empty for the five days between — and in the off-season it would leave
/// no reload date at all.
///
/// **Forty-eight hours has been reasoned, not soaked.** The reload mechanism itself was watched
/// firing on 2026-08-17 by forcing the truncation branch down to a nine-minute reload date (the
/// method is in `docs/guides/testing.md`), and nothing about `.after(_:)` distinguishes nine
/// minutes from two days. What has never been observed is a device left alone for the full
/// interval, so if a widget is ever found showing content two days stale, start here.
private let timelineHorizon: TimeInterval = 48 * 3600

/// Backstop on the entry count, not the working limit. Inside 48 hours the real feed produces at
/// most ~13 boundaries (a sprint weekend's six sessions, each with a start and an end, plus the
/// recently-finished expiry). Anything approaching this cap means the feed is not what we think
/// it is, and truncating is better than handing WidgetKit an unbounded archive.
private let maxTimelineEntries = 24

// MARK: - Provider

struct NoSpoilersTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> NoSpoilersEntry {
        placeholderEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (NoSpoilersEntry) -> Void) {
        let now = Date()
        guard !context.isPreview else {
            completion(placeholderEntry(at: now))
            return
        }
        Task {
            completion(makeEntry(at: now, data: await resolveWidgetData()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NoSpoilersEntry>) -> Void) {
        Task {
            completion(await buildTimeline())
        }
    }

    /// What is left of this once the plan is `TimelinePlanner`'s: fetch the data, turn each planned
    /// moment into a rendered entry, and hand WidgetKit the result. Every date decision above is
    /// unit-tested in `TimelinePlannerTests`; nothing here re-derives one.
    private func buildTimeline() async -> Timeline<NoSpoilersEntry> {
        let now = Date()
        let data = await resolveWidgetData()

        let plan = TimelinePlanner.plan(
            at: now,
            weekends: data.weekends,
            confirmedEndDates: data.confirmedEndDates,
            horizon: timelineHorizon,
            maxEntries: maxTimelineEntries
        )
        let entries = plan.entryDates.map { makeEntry(at: $0, data: data) }

        // The facts that make a stale widget diagnosable, on one line, at `.notice` so they are
        // still there tomorrow. Nothing is attached when a widget goes wrong: the app is not
        // running, and "showing last week" looks identical to "nothing happened". This line is the
        // difference. `truncated` is here because the cap changes which of two reload dates was
        // chosen, and the real feed has never once reached it.
        AppLog.widget.notice("timeline built", [
            "now": now,
            "weekends": data.weekends.count,
            "boundaries": plan.boundaryCount,
            "entries": entries.count,
            "truncated": plan.truncated,
            "horizon": plan.horizon,
            "reloadAt": plan.reloadAt,
            // What the user is actually looking at, so a trace answers "showing last week"
            // without anyone having to re-derive it from the entry dates.
            "showing": entries.first?.weekend,
        ])

        return Timeline(entries: entries, policy: .after(plan.reloadAt))
    }
}

// MARK: - Entry View

struct NoSpoilersWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: NoSpoilersEntry

    var body: some View {
        if let weekend = entry.weekend {
            switch family {
            case .systemSmall:
                smallView(weekend)
            case .systemLarge:
                largeView(weekend)
            case .systemExtraLarge:
                extraLargeView(weekend)
            default:
                mediumView(weekend)
            }
        } else if entry.isOffSeason {
            offSeasonView
        } else {
            noDataView
        }
    }

    // MARK: - Family views

    /// systemSmall — one glanceable answer: GP name as the hero, one session anchored at the bottom.
    @ViewBuilder
    private func smallView(_ weekend: RaceWeekend) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row: flag + round pill
            HStack(alignment: .center, spacing: 6) {
                FlagImage(countryCode: weekend.countryCode, height: 16)
                Spacer(minLength: 0)
                NoSpoilersRoundPill(NoSpoilersCore.Strings.Schedule.roundLabel(weekend.round))
            }

            Spacer(minLength: 8)

            // Hero: GP name fills available vertical space
            Text(weekend.grandPrixName)
                .font(.title3.weight(.bold))
                .foregroundStyle(BrandPalette.smoke)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            // Bottom: flat session row, no nested card
            if let primary = primarySession() {
                smallSessionRow(primary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Flat two-line session row for systemSmall — name above, time below, no nested card.
    private func smallSessionRow(_ session: SessionViewModel) -> some View {
        HStack(alignment: .center, spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor(for: session.state))
                .frame(width: 3, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.shortName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandPalette.smoke)
                    .lineLimit(1)
                smallSessionTime(session.state)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func smallSessionTime(_ state: SessionState) -> some View {
        switch state {
        case .finished(let endedAt):
            Text(endedAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(BrandPalette.secondaryText)
        case .live:
            Text(NoSpoilersCore.Strings.Schedule.inProgress)
                .font(.caption2)
                .foregroundStyle(widgetRed)
        case .upcoming(let startsAt):
            Text(startsAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(BrandPalette.secondaryText)
        }
    }

    /// systemMedium — header + up to 2 sessions + optional next-weekend footer.
    @ViewBuilder
    private func mediumView(_ weekend: RaceWeekend) -> some View {
        let sessions = prioritizedSessions(limit: 2)
        VStack(alignment: .leading, spacing: 6) {
            widgetHeader(weekend, compact: true)
            VStack(spacing: 4) {
                ForEach(sessions) { session in
                    widgetSessionRow(session, compact: true)
                }
            }
            Spacer(minLength: 0)
            if let upcoming = entry.nextWeekend {
                Divider()
                widgetComingUp(upcoming, compact: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// systemLarge — expanded header, full session list, next-weekend footer.
    @ViewBuilder
    private func largeView(_ weekend: RaceWeekend) -> some View {
        let visibleSessions = Array(entry.sessions.prefix(5))
        let hiddenCount = max(0, entry.sessions.count - visibleSessions.count)
        VStack(alignment: .leading, spacing: 8) {
            widgetHeader(weekend, compact: false)
            Divider()
            VStack(spacing: 4) {
                ForEach(visibleSessions) { session in
                    widgetSessionRow(session, compact: false)
                }
                if hiddenCount > 0 {
                    Text(Strings.Widget.moreSessions(hiddenCount))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(BrandPalette.secondaryText)
                        .padding(.horizontal, 8)
                }
            }
            Spacer(minLength: 0)
            if let upcoming = entry.nextWeekend {
                Divider()
                widgetComingUp(upcoming, compact: false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// systemExtraLarge — two-zone: left = full current weekend, right = next weekend.
    @ViewBuilder
    private func extraLargeView(_ weekend: RaceWeekend) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                widgetHeader(weekend, compact: false)
                Divider()
                VStack(spacing: 4) {
                    ForEach(entry.sessions) { session in
                        widgetSessionRow(session, compact: false)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)

            Divider()

            if let upcoming = entry.nextWeekend {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NoSpoilersCore.Strings.Schedule.comingUp)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(widgetRed)
                        .textCase(.uppercase)
                    FlagImage(countryCode: upcoming.countryCode, height: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(upcoming.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BrandPalette.smoke)
                            .lineLimit(2)
                        HStack(spacing: 4) {
                            NoSpoilersRoundPill(NoSpoilersCore.Strings.Schedule.roundLabel(upcoming.round))
                            Text(upcoming.location)
                                .font(.caption2)
                                .foregroundStyle(BrandPalette.secondaryText)
                                .lineLimit(1)
                        }
                        Text(upcoming.startsAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(BrandPalette.secondaryText)
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: 140)
            } else {
                Spacer().frame(width: 140)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var offSeasonView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                NoSpoilersRoundPill(Strings.OffSeason.badge)
                Spacer()
                Image(systemName: "flag.checkered.2.crossed")
                    .foregroundStyle(widgetRed)
            }
            Text(Strings.OffSeason.body)
                .font(.caption2)
                .foregroundStyle(BrandPalette.secondaryText)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var noDataView: some View {
        VStack(alignment: .center, spacing: 8) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.title2)
                .foregroundStyle(BrandPalette.tertiaryText)
            Text(NoSpoilersCore.Strings.Schedule.unavailableTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandPalette.smoke)
            Text(Strings.Error.unavailableBody)
                .font(.caption2)
                .foregroundStyle(BrandPalette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Shared view helpers

    /// Header used by all families.
    /// compact (small/medium): flag + GP name + round pill in a single row.
    /// expanded (large/XL): flag + GP name + round/location/dates stacked.
    @ViewBuilder
    private func widgetHeader(_ weekend: RaceWeekend, compact: Bool) -> some View {
        if compact {
            HStack(alignment: .center, spacing: 6) {
                FlagImage(countryCode: weekend.countryCode, height: 14)
                Text(weekend.grandPrixName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BrandPalette.smoke)
                    .lineLimit(1)
                Spacer(minLength: 0)
                NoSpoilersRoundPill(NoSpoilersCore.Strings.Schedule.roundLabel(weekend.round))
            }
        } else {
            HStack(alignment: .center, spacing: 10) {
                FlagImage(countryCode: weekend.countryCode, height: 20)
                VStack(alignment: .leading, spacing: 3) {
                    Text(weekend.grandPrixName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandPalette.smoke)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        NoSpoilersRoundPill(NoSpoilersCore.Strings.Schedule.roundLabel(weekend.round))
                        Text(weekend.location)
                            .font(.caption2)
                            .foregroundStyle(BrandPalette.secondaryText)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(sessionDateRange(for: weekend))
                            .font(.caption2)
                            .foregroundStyle(BrandPalette.tertiaryText)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private func widgetSessionRow(_ session: SessionViewModel, compact: Bool) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor(for: session.state))
                .frame(width: 3, height: compact ? 24 : 26)
            VStack(alignment: .leading, spacing: compact ? 2 : 3) {
                Text(compact ? session.shortName : session.name)
                    .font((compact ? Font.caption : .subheadline).weight(.medium))
                    .foregroundStyle(BrandPalette.smoke)
                    .lineLimit(1)

                if compact, shouldShowSecondaryName(for: session) {
                    Text(session.name)
                        .font(.caption2)
                        .foregroundStyle(BrandPalette.secondaryText)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            stateLabel(session.state, compact: compact)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.65))
        )
    }

    @ViewBuilder
    private func widgetComingUp(_ weekend: UpcomingWeekendViewModel, compact: Bool) -> some View {
        if compact {
            HStack(spacing: 6) {
                FlagImage(countryCode: weekend.countryCode, height: 12)
                Text(weekend.name)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(BrandPalette.smoke)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(weekend.startsAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(BrandPalette.secondaryText)
                    .lineLimit(1)
            }
        } else {
            HStack(spacing: 8) {
                FlagImage(countryCode: weekend.countryCode, height: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(NoSpoilersCore.Strings.Schedule.comingUp)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(widgetRed)
                        .textCase(.uppercase)
                    Text(weekend.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BrandPalette.smoke)
                        .lineLimit(1)
                    Text(weekend.startsAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(BrandPalette.secondaryText)
                }
                Spacer()
                NoSpoilersRoundPill(NoSpoilersCore.Strings.Schedule.roundLabel(weekend.round))
            }
        }
    }

    private func sessionDateRange(for weekend: RaceWeekend) -> String {
        guard let first = weekend.allSessions.first, let last = weekend.allSessions.last else {
            return weekend.location
        }
        let format = Date.FormatStyle().day().month(.abbreviated)
        let start = first.startsAt.formatted(format)
        let end = last.startsAt.formatted(format)
        return start == end ? start : Strings.Widget.dateRange(start: start, end: end)
    }

    private func accentColor(for state: SessionState) -> Color {
        switch state {
        case .finished:
            return BrandPalette.successGreen.opacity(0.75)
        case .live:
            return widgetRed
        case .upcoming:
            return BrandPalette.upcomingBlue
        }
    }

    private func primarySession() -> SessionViewModel? {
        entry.sessions.first {
            if case .finished = $0.state { return false }
            return true
        } ?? entry.sessions.last  // all finished: show most recent (Race), not oldest (FP1)
    }

    private func prioritizedSessions(limit: Int) -> [SessionViewModel] {
        let active = entry.sessions.filter {
            if case .finished = $0.state { return false }
            return true
        }
        if active.count >= limit {
            return Array(active.prefix(limit))
        }
        // Pad with most recently finished first (reverse chronological), not oldest first
        let recentFinished = entry.sessions.filter {
            if case .finished = $0.state { return true }
            return false
        }.reversed()
        return Array((active + recentFinished).prefix(limit))
    }

    private func shouldShowSecondaryName(for session: SessionViewModel) -> Bool {
        let shortName = normalizedSessionLabel(session.shortName)
        let fullName = normalizedSessionLabel(session.name)
        guard !shortName.isEmpty, !fullName.isEmpty else { return false }
        return !fullName.contains(shortName) && !shortName.contains(fullName)
    }

    private func normalizedSessionLabel(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "", options: .regularExpression)
    }

    @ViewBuilder
    private func stateLabel(_ state: SessionState, compact: Bool) -> some View {
        switch state {
        case .finished(let endedAt):
            if compact {
                NoSpoilersStatusBadge(textKey: Strings.Sessions.finished, style: .finished, compact: true)
            } else {
                NoSpoilersStatusBadge(
                    text: Text(Strings.Sessions.finished) + Text(verbatim: " · ") + Text(endedAt, style: .relative),
                    style: .finished,
                    compact: false
                )
            }
        case .live:
            NoSpoilersStatusBadge(textKey: NoSpoilersCore.Strings.Schedule.inProgress, style: .live, compact: compact)
        case .upcoming(let startsAt):
            NoSpoilersStatusBadge(text: Text(startsAt, style: .relative), style: .upcoming, compact: compact)
        }
    }
}

// MARK: - Widget

struct NoSpoilersWidget: Widget {
    let kind: String = NoSpoilersConfig.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NoSpoilersTimelineProvider()) { entry in
            NoSpoilersWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    NoSpoilersBackground()
                }
        }
        .configurationDisplayName(Strings.Widget.displayName)
        .description(Strings.Widget.widgetDescription)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Previews

struct NoSpoilersWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NoSpoilersWidgetEntryView(entry: placeholderEntry())
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small")

            NoSpoilersWidgetEntryView(entry: placeholderEntry())
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium")

            NoSpoilersWidgetEntryView(entry: placeholderEntry())
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .previewDisplayName("Large")

            NoSpoilersWidgetEntryView(entry: placeholderEntry())
                .previewContext(WidgetPreviewContext(family: .systemExtraLarge))
                .previewDisplayName("Extra Large")
        }
        .containerBackground(for: .widget) {
            NoSpoilersBackground()
        }
    }
}
