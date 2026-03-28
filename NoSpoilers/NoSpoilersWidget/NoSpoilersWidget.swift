import WidgetKit
import SwiftUI
import NoSpoilersCore

private let widgetRed = Color(red: 0.93, green: 0, blue: 0)
private let widgetCream = Color(red: 0.99, green: 0.97, blue: 0.95)

// MARK: - Entry

struct NoSpoilersEntry: TimelineEntry {
    let date: Date
    let weekend: RaceWeekend?
    let sessions: [SessionViewModel]
    let offSeasonNextRace: SessionViewModel?
}

// MARK: - View Models

struct SessionViewModel: Identifiable {
    let id: String
    let name: String
    let state: SessionState
}

enum SessionState {
    case finished(ago: String)         // "2h ago"
    case live
    case upcoming(countdown: String)   // "in 4h 23m"
    case offSeason(daysUntil: String)  // "in 12 days"
}

// MARK: - Helpers

private func sessionState(for session: Session, nextSession: Session?, at now: Date, confirmedEndDates: [String: Date]) -> SessionState {
    switch SessionResolver.status(for: session, at: now, nextSession: nextSession, confirmedEndAt: confirmedEndDates[session.id]) {
    case .finished:
        let secs = Int(now.timeIntervalSince(session.endsAt))
        let h = secs / 3600
        let m = (secs % 3600) / 60
        return .finished(ago: h > 0 ? "\(h)h ago" : "\(m)m ago")
    case .inProgress:
        return .live
    case .upcoming:
        let secs = Int(session.startsAt.timeIntervalSince(now))
        let h = secs / 3600
        let m = (secs % 3600) / 60
        return .upcoming(countdown: h > 0 ? "in \(h)h \(m)m" : "in \(m)m")
    }
}

private func makeEntry(at now: Date) -> NoSpoilersEntry {
    let weekends = (try? ScheduleCache().load(for: NoSpoilersConfig.appGroupID)) ?? []
    let confirmedEndDates = SessionEndConfirmer.loadStoredDates(appGroupID: NoSpoilersConfig.appGroupID)

    guard let weekend = RaceWeekendResolver.firstActiveWeekend(in: weekends, at: now, confirmedEndDates: confirmedEndDates),
          let firstActiveSession = RaceWeekendResolver.firstNonFinishedSession(in: weekend, at: now, confirmedEndDates: confirmedEndDates)
    else {
        return NoSpoilersEntry(date: now, weekend: nil, sessions: [], offSeasonNextRace: nil)
    }

    let sorted = weekend.allSessions
    if firstActiveSession.startsAt.timeIntervalSince(now) > 7 * 86_400 {
        let days = Int(firstActiveSession.startsAt.timeIntervalSince(now) / 86_400)
        let vm = SessionViewModel(id: firstActiveSession.id, name: weekend.grandPrixName,
                                  state: .offSeason(daysUntil: "in \(days) days"))
        return NoSpoilersEntry(date: now, weekend: nil, sessions: [], offSeasonNextRace: vm)
    }

    let sessionVMs = sorted.indices.map { i in
        let s = sorted[i]
        let next = i + 1 < sorted.count ? sorted[i + 1] : nil
        return SessionViewModel(id: s.id, name: s.kind.displayName, state: sessionState(for: s, nextSession: next, at: now, confirmedEndDates: confirmedEndDates))
    }
    return NoSpoilersEntry(date: now, weekend: weekend, sessions: sessionVMs, offSeasonNextRace: nil)
}

private func nextReloadDate(after now: Date) -> Date {
    let allSessions = ((try? ScheduleCache().load(for: NoSpoilersConfig.appGroupID)) ?? [])
        .flatMap(\.allSessions).sorted { $0.startsAt < $1.startsAt }
    let confirmedEndDates = SessionEndConfirmer.loadStoredDates(appGroupID: NoSpoilersConfig.appGroupID)
    // Find the inProgress session (if any) using the resolver
    let currentIdx = allSessions.indices.first(where: { i in
        let next = i + 1 < allSessions.count ? allSessions[i + 1] : nil
        return SessionResolver.status(for: allSessions[i], at: now, nextSession: next, confirmedEndAt: confirmedEndDates[allSessions[i].id]) == .inProgress
    })
    let nextSession = allSessions.first { $0.startsAt > now }
    if let idx = currentIdx {
        let session = allSessions[idx]
        // If we have a confirmed end, reload at that time; otherwise use grace window end
        let reloadAt = confirmedEndDates[session.id] ?? (session.endsAt + session.kind.gracePeriod)
        return [reloadAt, nextSession?.startsAt].compactMap { $0 }.min()
            ?? Calendar.current.date(byAdding: .hour, value: 1, to: now)!
    }
    return nextSession?.startsAt
        ?? Calendar.current.date(byAdding: .hour, value: 1, to: now)!
}

// MARK: - Provider

struct NoSpoilersTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> NoSpoilersEntry {
        NoSpoilersEntry(date: Date(), weekend: nil, sessions: [], offSeasonNextRace: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (NoSpoilersEntry) -> Void) {
        completion(makeEntry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NoSpoilersEntry>) -> Void) {
        let now = Date()
        completion(Timeline(entries: [makeEntry(at: now)], policy: .after(nextReloadDate(after: now))))
    }
}

// MARK: - Views

struct NoSpoilersWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: NoSpoilersEntry

    var body: some View {
        if let offSeason = entry.offSeasonNextRace {
            offSeasonView(offSeason)
        } else if entry.weekend != nil {
            if family == .systemSmall { smallView } else { mediumView }
        } else {
            noDataView
        }
    }

    @ViewBuilder
    private func offSeasonView(_ next: SessionViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Off-season")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(widgetRed)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(widgetRed.opacity(0.12))
                    .clipShape(Capsule())
                Spacer()
                Image(systemName: "flag.checkered.2.crossed")
                    .foregroundStyle(widgetRed)
            }
            Text(next.name)
                .font(.headline)
                .fontWeight(.semibold)
            if case .offSeason(let d) = next.state {
                Text(d)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text("The next race weekend will appear here as soon as it gets close enough to matter.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(16)
    }

    @ViewBuilder
    private var smallView: some View {
        let next = entry.sessions.first { if case .finished = $0.state { return false }; return true }
                   ?? entry.sessions.first
        VStack(alignment: .leading, spacing: 12) {
            if let weekend = entry.weekend {
                compactHeader(weekend)
            }
            if let s = next {
                featuredSessionCard(s)
            }
            if let weekend = entry.weekend {
                Text(sessionDateRange(for: weekend))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
    }

    @ViewBuilder
    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let weekend = entry.weekend {
                fullHeader(weekend)
            }
            VStack(spacing: 6) {
                ForEach(entry.sessions.prefix(5)) { session in
                    sessionRow(session)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
    }

    @ViewBuilder
    private var noDataView: some View {
        VStack(spacing: 10) {
            Image(systemName: "flag.checkered.2.crossed")
                .font(.system(size: 28))
                .foregroundStyle(widgetRed)
            Text("Schedule unavailable")
                .font(.headline)
            Text("Open the app to refresh the shared schedule cache.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }

    private func compactHeader(_ weekend: RaceWeekend) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text("R\(weekend.round)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(widgetRed)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(widgetRed.opacity(0.12))
                    .clipShape(Capsule())
                Spacer()
                Text(weekend.countryFlag)
                    .font(.title3)
            }
            Text(weekend.grandPrixName)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(2)
        }
    }

    private func fullHeader(_ weekend: RaceWeekend) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Text("R\(weekend.round)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(widgetRed)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(widgetRed.opacity(0.12))
                    .clipShape(Capsule())
                Text(weekend.location)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Text(weekend.countryFlag)
                    .font(.title2)
            }

            Text(weekend.grandPrixName)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)

            Text(sessionDateRange(for: weekend))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func featuredSessionCard(_ session: SessionViewModel) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor(for: session.state))
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 6) {
                Text(session.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                stateBadge(session.state)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.58))
        )
    }

    private func sessionRow(_ session: SessionViewModel) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor(for: session.state))
                .frame(width: 3, height: 28)
            Text(session.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
            Spacer(minLength: 8)
            stateLabel(session.state)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }

    private func sessionDateRange(for weekend: RaceWeekend) -> String {
        guard let first = weekend.allSessions.first, let last = weekend.allSessions.last else {
            return weekend.location
        }
        let format = Date.FormatStyle().day().month(.abbreviated)
        let start = first.startsAt.formatted(format)
        let end = last.startsAt.formatted(format)
        return start == end ? start : "\(start) → \(end)"
    }

    private func accentColor(for state: SessionState) -> Color {
        switch state {
        case .finished:
            return .green.opacity(0.75)
        case .live:
            return widgetRed
        case .upcoming, .offSeason:
            return .blue.opacity(0.7)
        }
    }

    @ViewBuilder
    private func stateLabel(_ state: SessionState) -> some View {
        switch state {
        case .finished(let ago):
            VStack(alignment: .trailing, spacing: 1) {
                Text("Finished").font(.caption2).foregroundStyle(.green)
                Text(ago).font(.caption2).foregroundStyle(.secondary)
            }
        case .live:
            Text("In Progress")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(widgetRed)
                .clipShape(Capsule())
        case .upcoming(let c):
            Text(c)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Capsule())
        case .offSeason(let d):
            Text(d)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private func stateBadge(_ state: SessionState) -> some View {
        switch state {
        case .finished(let ago):
            VStack(alignment: .leading, spacing: 2) {
                Text("Finished")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.green)
                Text(ago)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .live:
            Text("In Progress")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(widgetRed)
                .clipShape(Capsule())
        case .upcoming(let c):
            Text(c)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Capsule())
        case .offSeason(let d):
            Text(d)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Capsule())
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
                    LinearGradient(
                        colors: [
                            widgetCream,
                            Color.white,
                            widgetRed.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("No Spoilers")
        .description("F1 race weekend sessions — no results.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
