import WidgetKit
import SwiftUI
import OSLog
import NoSpoilersCore

private let log = Logger(subsystem: "pomocorp.NoSpoilers.NoSpoilersWidget", category: "data")

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
    let countryCode: String
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

private func effectiveSessionEndDate(
    for session: Session,
    nextSession: Session?,
    confirmedEndDates: [String: Date]
) -> Date {
    let fallbackEnd = confirmedEndDates[session.id] ?? (session.endsAt + session.kind.gracePeriod)
    guard let nextSession else {
        return fallbackEnd
    }
    return min(nextSession.startsAt, fallbackEnd)
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
    let allSessions: [Session]
    let confirmedEndDates: [String: Date]
}

private struct WidgetFeedResponse: Codable {
    let races: [RaceWeekend]
}

/// Reads weekends from the shared cache; if the cache is empty or inaccessible, fetches
/// from the network synchronously and writes back to cache so the next reload is fast.
private func resolveWidgetData() -> WidgetDataSnapshot {
    let cache = ScheduleCache()
    let confirmedEndDates = SessionEndConfirmer.loadStoredDates(appGroupID: NoSpoilersConfig.appGroupID)

    let cacheResult = Result { try cache.load(for: NoSpoilersConfig.appGroupID) }
    switch cacheResult {
    case .success(let weekends) where !weekends.isEmpty:
        log.error("cache hit: \(weekends.count) weekends")
        return WidgetDataSnapshot(
            weekends: weekends,
            allSessions: weekends.flatMap(\.allSessions).sorted { $0.startsAt < $1.startsAt },
            confirmedEndDates: confirmedEndDates
        )
    case .success:
        log.error("cache empty — falling back to network fetch")
    case .failure(let error):
        log.error("cache load failed: \(error) — falling back to network fetch")
    }

    // Cache miss or App Group unavailable — fetch directly so the widget does not need the app to run first.
    let feedURL = URL(string: "https://raw.githubusercontent.com/sportstimes/f1/main/_db/f1/2026.json")!
    var weekends: [RaceWeekend] = []
    var fetchStatus: Int?
    var fetchError: Error?
    let semaphore = DispatchSemaphore(value: 0)
    // Use ephemeral config — Apple recommends against URLSession.shared in extension contexts.
    let session = URLSession(configuration: .ephemeral)
    session.dataTask(with: feedURL) { bytes, response, error in
        fetchStatus = (response as? HTTPURLResponse)?.statusCode
        fetchError = error
        if let bytes, fetchStatus == 200 {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            weekends = (try? decoder.decode(WidgetFeedResponse.self, from: bytes))?.races.sorted { $0.round < $1.round } ?? []
        }
        semaphore.signal()
    }.resume()
    let waitResult = semaphore.wait(timeout: .now() + 8)

    if waitResult == .timedOut {
        log.error("network fetch timed out after 8s")
    } else if let error = fetchError {
        log.error("network fetch error: \(error)")
    } else {
        log.error("network fetch: HTTP \(fetchStatus ?? -1), decoded \(weekends.count) weekends")
    }

    // Persist back to cache so the next timeline request skips the fetch.
    do {
        try cache.save(weekends, for: NoSpoilersConfig.appGroupID)
        log.error("wrote \(weekends.count) weekends back to cache")
    } catch {
        log.error("cache save failed: \(error)")
    }

    return WidgetDataSnapshot(
        weekends: weekends,
        allSessions: weekends.flatMap(\.allSessions).sorted { $0.startsAt < $1.startsAt },
        confirmedEndDates: confirmedEndDates
    )
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
    }), let lastSession = previous.allSessions.last {
        let endTime = effectiveSessionEndDate(for: lastSession, nextSession: nil, confirmedEndDates: confirmedEndDates)
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

private func timelineBoundaryDates(after now: Date, data: WidgetDataSnapshot) -> [Date] {
    var candidates: [Date] = [now]

    for weekend in data.weekends {
        // Schedule the boundary where the 24h "recently finished" window expires.
        if let lastSession = weekend.allSessions.last {
            let endTime = effectiveSessionEndDate(for: lastSession, nextSession: nil, confirmedEndDates: data.confirmedEndDates)
            let expiryTime = endTime.addingTimeInterval(24 * 3600)
            if expiryTime > now {
                candidates.append(expiryTime)
            }
        }
    }

    for index in data.allSessions.indices {
        let session = data.allSessions[index]
        let nextSession = index + 1 < data.allSessions.count ? data.allSessions[index + 1] : nil

        if session.startsAt > now {
            candidates.append(session.startsAt)
        }

        let finishedAt = effectiveSessionEndDate(
            for: session,
            nextSession: nextSession,
            confirmedEndDates: data.confirmedEndDates
        )
        if finishedAt > now {
            candidates.append(finishedAt)
        }
    }

    let unique = Set(candidates.map { $0.timeIntervalSinceReferenceDate })
        .map(Date.init(timeIntervalSinceReferenceDate:))
        .sorted()

    return unique
}

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
        completion(makeEntry(at: now, data: resolveWidgetData()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NoSpoilersEntry>) -> Void) {
        let now = Date()
        let data = resolveWidgetData()
        let entries = timelineBoundaryDates(after: now, data: data).map { makeEntry(at: $0, data: data) }
        let policy: TimelineReloadPolicy = entries.isEmpty ? .after(now.addingTimeInterval(900)) : .atEnd
        completion(Timeline(entries: entries, policy: policy))
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

    /// systemSmall — one glanceable answer: GP name + primary session only.
    @ViewBuilder
    private func smallView(_ weekend: RaceWeekend) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            widgetHeader(weekend, compact: true)
            Divider()
            if let primary = primarySession() {
                widgetSessionRow(primary, compact: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                    Text(Strings.Widget.comingUp)
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
                            NoSpoilersRoundPill(Strings.Sessions.roundLabel(upcoming.round))
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
            Text(Strings.Error.unavailableTitle)
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
                NoSpoilersRoundPill(Strings.Sessions.roundLabel(weekend.round))
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
                        NoSpoilersRoundPill(Strings.Sessions.roundLabel(weekend.round))
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

    private func widgetComingUp(_ weekend: UpcomingWeekendViewModel, compact: Bool) -> some View {
        HStack(spacing: 8) {
            FlagImage(countryCode: weekend.countryCode, height: compact ? 16 : 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(Strings.Widget.comingUp)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(compact ? BrandPalette.tertiaryText : widgetRed)
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
            NoSpoilersRoundPill(Strings.Sessions.roundLabel(weekend.round))
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
        } ?? entry.sessions.first
    }

    private func prioritizedSessions(limit: Int) -> [SessionViewModel] {
        let active = entry.sessions.filter {
            if case .finished = $0.state { return false }
            return true
        }
        if active.count >= limit {
            return Array(active.prefix(limit))
        }
        let finished = entry.sessions.filter {
            if case .finished = $0.state { return true }
            return false
        }
        return Array((active + finished).prefix(limit))
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
            NoSpoilersStatusBadge(
                text: Text(Strings.Sessions.finished) + Text(verbatim: " · ") + Text(endedAt, style: .relative),
                style: .finished,
                compact: compact
            )
        case .live:
            NoSpoilersStatusBadge(textKey: Strings.Sessions.inProgress, style: .live, compact: compact)
        case .upcoming(let startsAt):
            NoSpoilersStatusBadge(text: Text(startsAt, style: .relative), style: .upcoming, compact: compact)
        }
    }
}

// MARK: - Widget

struct NoSpoilersWidget: Widget {
    let kind: String = "NoSpoilersWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NoSpoilersTimelineProvider()) { entry in
            NoSpoilersWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    NoSpoilersBackground()
                }
        }
        .configurationDisplayName(Strings.Widget.displayName)
        .description(Strings.Widget.widgetDescription)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
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
