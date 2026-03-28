import WidgetKit
import SwiftUI
import NoSpoilersCore

private let appGroupID = "group.pomocorp.no-spoilers"

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

private func sessionState(for session: Session, at now: Date) -> SessionState {
    if session.endsAt < now {
        let secs = Int(now.timeIntervalSince(session.endsAt))
        let h = secs / 3600
        let m = (secs % 3600) / 60
        return .finished(ago: h > 0 ? "\(h)h ago" : "\(m)m ago")
    } else if session.startsAt <= now {
        return .live
    } else {
        let secs = Int(session.startsAt.timeIntervalSince(now))
        let h = secs / 3600
        let m = (secs % 3600) / 60
        return .upcoming(countdown: h > 0 ? "in \(h)h \(m)m" : "in \(m)m")
    }
}

private func makeEntry(at now: Date) -> NoSpoilersEntry {
    let weekends = (try? ScheduleCache().load(for: appGroupID)) ?? []

    // First weekend that still has at least one session with endsAt >= now
    guard let weekend = weekends.sorted(by: { $0.round < $1.round })
            .first(where: { $0.allSessions.contains { $0.endsAt >= now } })
    else {
        return NoSpoilersEntry(date: now, weekend: nil, sessions: [], offSeasonNextRace: nil)
    }

    // If next un-ended session is >7 days away, show off-season card
    if let nextSession = weekend.allSessions.first(where: { $0.endsAt >= now }),
       nextSession.startsAt.timeIntervalSince(now) > 7 * 86_400 {
        let days = Int(nextSession.startsAt.timeIntervalSince(now) / 86_400)
        let vm = SessionViewModel(id: nextSession.id, name: weekend.grandPrixName,
                                  state: .offSeason(daysUntil: "in \(days) days"))
        return NoSpoilersEntry(date: now, weekend: nil, sessions: [], offSeasonNextRace: vm)
    }

    let sessionVMs = weekend.allSessions.map { s in
        SessionViewModel(id: s.id, name: s.kind.displayName, state: sessionState(for: s, at: now))
    }
    return NoSpoilersEntry(date: now, weekend: weekend, sessions: sessionVMs, offSeasonNextRace: nil)
}

private func nextReloadDate(after now: Date) -> Date {
    let allSessions = ((try? ScheduleCache().load(for: appGroupID)) ?? [])
        .flatMap(\.allSessions).sorted { $0.startsAt < $1.startsAt }
    let current = allSessions.first { $0.startsAt <= now && now < $0.endsAt }
    let next    = allSessions.first { $0.startsAt > now }
    return [current?.endsAt, next?.startsAt].compactMap { $0 }.min()
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
        VStack(alignment: .leading, spacing: 4) {
            Text("Off-season").font(.caption).foregroundStyle(.secondary)
            Text(next.name).font(.headline)
            if case .offSeason(let d) = next.state {
                Text(d).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
    }

    @ViewBuilder
    private var smallView: some View {
        let next = entry.sessions.first { if case .finished = $0.state { return false }; return true }
                   ?? entry.sessions.first
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.weekend?.name ?? "").font(.caption).foregroundStyle(.secondary)
            if let s = next {
                Text(s.name).font(.headline)
                stateLabel(s.state)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
    }

    @ViewBuilder
    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.weekend?.grandPrixName ?? "")
                .font(.caption).foregroundStyle(.secondary).padding(.bottom, 2)
            ForEach(entry.sessions) { s in
                HStack { Text(s.name).font(.caption2); Spacer(); stateLabel(s.state) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }

    @ViewBuilder
    private var noDataView: some View {
        Text("Schedule unavailable\nOpen app to refresh")
            .font(.caption).multilineTextAlignment(.center).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func stateLabel(_ state: SessionState) -> some View {
        switch state {
        case .finished(let ago):
            VStack(alignment: .trailing, spacing: 1) {
                Text("Finished").font(.caption2).foregroundStyle(.green)
                Text(ago).font(.caption2).foregroundStyle(.secondary)
            }
        case .live:              Text("Now").font(.caption2).foregroundStyle(.orange)
        case .upcoming(let c):   Text(c).font(.caption2).foregroundStyle(.secondary)
        case .offSeason(let d):  Text(d).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Widget

struct NoSpoilersWidget: Widget {
    let kind: String = "NoSpoilersWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NoSpoilersTimelineProvider()) { entry in
            NoSpoilersWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("No Spoilers")
        .description("F1 race weekend sessions — no results.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
