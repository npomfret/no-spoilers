import WidgetKit
import SwiftUI
import NoSpoilersCore

private let widgetRed = BrandPalette.signalRed

private enum WidgetLayout {
    static let outerPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 12
    static let cardSpacing: CGFloat = 10
    static let cardHorizontalPadding: CGFloat = 10
    static let cardVerticalPadding: CGFloat = 10
    static let cardCornerRadius: CGFloat = 14
}

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

private func loadWidgetData() -> WidgetDataSnapshot {
    let weekends = (try? ScheduleCache().load(for: NoSpoilersConfig.appGroupID)) ?? []
    return WidgetDataSnapshot(
        weekends: weekends,
        allSessions: weekends.flatMap(\.allSessions).sorted { $0.startsAt < $1.startsAt },
        confirmedEndDates: SessionEndConfirmer.loadStoredDates(appGroupID: NoSpoilersConfig.appGroupID)
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
                return UpcomingWeekendViewModel(round: w.round, countryCode: w.countryCode, name: w.grandPrixName, startsAt: first.startsAt)
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
        return UpcomingWeekendViewModel(round: w.round, countryCode: w.countryCode, name: w.grandPrixName, startsAt: first.startsAt)
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

        let data = loadWidgetData()
        completion(makeEntry(at: now, data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NoSpoilersEntry>) -> Void) {
        let now = Date()
        let data = loadWidgetData()
        let entries = timelineBoundaryDates(after: now, data: data).map { makeEntry(at: $0, data: data) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Views

struct NoSpoilersWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: NoSpoilersEntry

    var body: some View {
        if entry.weekend != nil {
            switch family {
            case .systemSmall:
                smallView
            case .systemMedium:
                mediumView
            case .systemLarge:
                largeView
            default:
                mediumView
            }
        } else if entry.isOffSeason {
            offSeasonView
        } else {
            noDataView
        }
    }

    @ViewBuilder
    private var offSeasonView: some View {
        NoSpoilersCard(density: .widget) {
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
            }
        }
        .padding(WidgetLayout.outerPadding)
    }

    @ViewBuilder
    private var smallView: some View {
        let primary = primarySession()
        NoSpoilersCard(density: .widget) {
            VStack(alignment: .leading, spacing: 12) {
                if let weekend = entry.weekend {
                    widgetHeader(weekend, wordmarkSize: .small, flagHeight: 16, titleFont: .caption.weight(.bold))
                } else {
                    NoSpoilersWordmark(size: .small)
                }

                Divider()

                if let primary {
                    widgetSessionRow(primary, compact: true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(WidgetLayout.outerPadding)
    }

    @ViewBuilder
    private var mediumView: some View {
        let sessions = prioritizedSessions(limit: 2)
        NoSpoilersCard(density: .widget) {
            VStack(alignment: .leading, spacing: 12) {
                if let weekend = entry.weekend {
                    widgetHeader(weekend, wordmarkSize: .small, flagHeight: 17, titleFont: .caption.weight(.bold))
                }

                VStack(spacing: 8) {
                    ForEach(sessions) { session in
                        widgetSessionRow(session, compact: true)
                    }
                }

                if let upcoming = entry.nextWeekend {
                    Divider()
                    widgetComingUp(upcoming, compact: true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(WidgetLayout.outerPadding)
    }

    @ViewBuilder
    private var largeView: some View {
        let visibleSessions = Array(entry.sessions.prefix(5))
        let hiddenCount = max(0, entry.sessions.count - visibleSessions.count)

        NoSpoilersCard(density: .widget) {
            VStack(alignment: .leading, spacing: 12) {
                if let weekend = entry.weekend {
                    widgetHeader(weekend, wordmarkSize: .medium, flagHeight: 20, titleFont: .headline.weight(.semibold))
                }

                VStack(spacing: 8) {
                    ForEach(visibleSessions) { session in
                        widgetSessionRow(session, compact: false)
                    }
                }

                if hiddenCount > 0 {
                    Text(Strings.Widget.moreSessions(hiddenCount))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(BrandPalette.secondaryText)
                }

                if let upcoming = entry.nextWeekend {
                    Divider()
                    widgetComingUp(upcoming, compact: false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(WidgetLayout.outerPadding)
    }

    @ViewBuilder
    private var noDataView: some View {
        NoSpoilersMessageCard(
            title: Text(Strings.Error.unavailableTitle),
            bodyText: Text(Strings.Error.unavailableBody),
            density: .widget
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(WidgetLayout.outerPadding)
    }

    private func widgetHeader(
        _ weekend: RaceWeekend,
        wordmarkSize: NoSpoilersWordmarkSize,
        flagHeight: CGFloat,
        titleFont: Font
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                NoSpoilersWordmark(size: wordmarkSize)
                Spacer()
                FlagImage(countryCode: weekend.countryCode, height: flagHeight)
            }

            Text(weekend.grandPrixName)
                .font(titleFont)
                .foregroundStyle(BrandPalette.smoke)
                .lineLimit(1)

            HStack(alignment: .center, spacing: 6) {
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
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(BrandPalette.blush.opacity(0.42))
        )
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
        .padding(.vertical, 6)
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
                    .foregroundStyle(compact ? BrandPalette.tertiaryText : BrandPalette.signalRed)
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

        guard !shortName.isEmpty, !fullName.isEmpty else {
            return false
        }

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
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
