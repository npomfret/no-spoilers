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

private func sessionState(for session: Session, nextSession: Session?, at now: Date) -> SessionState {
    switch SessionResolver.status(for: session, at: now, nextSession: nextSession) {
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
    let weekends = (try? ScheduleCache().load(for: appGroupID)) ?? []

    // First weekend that still has at least one session not yet finished (per resolver)
    guard let weekend = weekends.sorted(by: { $0.round < $1.round })
            .first(where: { w in
                let s = w.allSessions
                return s.indices.contains(where: { i in
                    SessionResolver.status(for: s[i], at: now, nextSession: i + 1 < s.count ? s[i + 1] : nil) != .finished
                })
            })
    else {
        return NoSpoilersEntry(date: now, weekend: nil, sessions: [], offSeasonNextRace: nil)
    }

    let sorted = weekend.allSessions
    // First session that isn't finished
    if let firstActiveIdx = sorted.indices.first(where: { i in
        SessionResolver.status(for: sorted[i], at: now, nextSession: i + 1 < sorted.count ? sorted[i + 1] : nil) != .finished
    }), sorted[firstActiveIdx].startsAt.timeIntervalSince(now) > 7 * 86_400 {
        let nextSession = sorted[firstActiveIdx]
        let days = Int(nextSession.startsAt.timeIntervalSince(now) / 86_400)
        let vm = SessionViewModel(id: nextSession.id, name: weekend.grandPrixName,
                                  state: .offSeason(daysUntil: "in \(days) days"))
        return NoSpoilersEntry(date: now, weekend: nil, sessions: [], offSeasonNextRace: vm)
    }

    let sessionVMs = sorted.indices.map { i in
        let s = sorted[i]
        let next = i + 1 < sorted.count ? sorted[i + 1] : nil
        return SessionViewModel(id: s.id, name: s.kind.displayName, state: sessionState(for: s, nextSession: next, at: now))
    }
    return NoSpoilersEntry(date: now, weekend: weekend, sessions: sessionVMs, offSeasonNextRace: nil)
}

private func nextReloadDate(after now: Date) -> Date {
    let allSessions = ((try? ScheduleCache().load(for: appGroupID)) ?? [])
        .flatMap(\.allSessions).sorted { $0.startsAt < $1.startsAt }
    // Find the inProgress session (if any) using the resolver
    let currentIdx = allSessions.indices.first(where: { i in
        let next = i + 1 < allSessions.count ? allSessions[i + 1] : nil
        return SessionResolver.status(for: allSessions[i], at: now, nextSession: next) == .inProgress
    })
    let nextSession = allSessions.first { $0.startsAt > now }
    if let idx = currentIdx {
        // Reload at end of grace window or next session start, whichever is sooner
        let graceEnd = allSessions[idx].endsAt + allSessions[idx].kind.gracePeriod
        return [graceEnd, nextSession?.startsAt].compactMap { $0 }.min()
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
