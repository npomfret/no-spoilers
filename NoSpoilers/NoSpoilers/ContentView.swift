import Combine
import SwiftUI
import WidgetKit
import NoSpoilersCore

private let f1Red = Color(red: 0.93, green: 0, blue: 0)
private let offSeasonThreshold: TimeInterval = 7 * 86_400

struct ContentView: View {
    @EnvironmentObject private var store: ScheduleStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var now = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let weekend = RaceWeekendResolver.firstActiveWeekend(in: store.weekends, at: now),
                       let firstSession = RaceWeekendResolver.firstNonFinishedSession(in: weekend, at: now) {
                        if firstSession.startsAt.timeIntervalSince(now) > offSeasonThreshold {
                            offSeasonView(weekend: weekend, session: firstSession)
                        } else {
                            weekendView(weekend)
                        }
                    } else {
                        unavailableView
                    }
                }
                .padding(16)
            }
            .refreshable { await refresh() }
            .background(backgroundGradient)
            .navigationTitle("No Spoilers")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task { await refresh() }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { tick in
            now = tick
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await refresh() }
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.97, green: 0.98, blue: 1.0),
                Color(red: 0.92, green: 0.94, blue: 0.98)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func weekendView(_ weekend: RaceWeekend) -> some View {
        let sessions = weekend.allSessions
        let nextWeekend = RaceWeekendResolver.nextWeekend(after: weekend, in: store.weekends)

        return VStack(spacing: 16) {
            headerCard(weekend: weekend, sessions: sessions)
            sessionCard(sessions: sessions)
            if let nextWeekend {
                nextWeekendCard(nextWeekend)
            }
        }
    }

    private func headerCard(weekend: RaceWeekend, sessions: [Session]) -> some View {
        let nextSession = RaceWeekendResolver.firstNonFinishedSession(in: weekend, at: now)
        let statusLine = nextSession.map { nextSessionStatus(for: $0, in: sessions) } ?? "Weekend complete"

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Round \(weekend.round)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(f1Red)
                    Text(weekend.grandPrixName)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(weekend.location)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(weekend.countryFlag)
                    .font(.system(size: 40))
            }

            Text(statusLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let first = sessions.first, let last = sessions.last {
                Text(dateRange(from: first.startsAt, to: last.startsAt))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func sessionCard(sessions: [Session]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sessions")
                .font(.headline)

            ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                let nextSession = index + 1 < sessions.count ? sessions[index + 1] : nil
                let status = SessionResolver.status(for: session, at: now, nextSession: nextSession)

                HStack(spacing: 12) {
                    Circle()
                        .fill(statusColor(status))
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.kind.displayName)
                            .font(.body.weight(.semibold))
                        Text(session.startsAt.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    statusBadge(for: session, status: status)
                }

                if session.id != sessions.last?.id {
                    Divider()
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func nextWeekendCard(_ weekend: RaceWeekend) -> some View {
        let firstSession = weekend.allSessions.first

        return VStack(alignment: .leading, spacing: 8) {
            Text("Coming up...")
                .font(.headline)
            HStack(spacing: 12) {
                Text(weekend.countryFlag)
                    .font(.title)
                VStack(alignment: .leading, spacing: 4) {
                    Text(weekend.grandPrixName)
                        .font(.subheadline.weight(.semibold))
                    if let firstSession {
                        Text(countdown(to: firstSession.startsAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(weekend.location)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text("R\(weekend.round)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(f1Red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(f1Red.opacity(0.12), in: Capsule())
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func offSeasonView(weekend: RaceWeekend, session: Session) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Off-season")
                .font(.headline)
            Text(weekend.grandPrixName)
                .font(.title2.weight(.bold))
            Text("Next session \(countdown(to: session.startsAt))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(weekend.location)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var unavailableView: some View {
        VStack(spacing: 12) {
            Image(systemName: "flag.checkered.2.crossed")
                .font(.system(size: 34))
                .foregroundStyle(f1Red)
            Text("Schedule unavailable")
                .font(.headline)
            Text("Pull to refresh or open the app again to update the shared widget cache.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    private func statusBadge(for session: Session, status: SessionStatus) -> some View {
        switch status {
        case .finished:
            Text("Finished \(finishedAgo(since: session.endsAt))")
                .font(.caption.weight(.medium))
                .foregroundStyle(.green)
        case .inProgress:
            Text("In Progress")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(f1Red, in: Capsule())
        case .upcoming:
            Text(countdown(to: session.startsAt))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.12), in: Capsule())
        }
    }

    private func nextSessionStatus(for session: Session, in sessions: [Session]) -> String {
        let nextSession = nextChronologicalSession(after: session, in: sessions)
        switch SessionResolver.status(for: session, at: now, nextSession: nextSession) {
        case .finished:
            return "\(session.kind.displayName) finished \(finishedAgo(since: session.endsAt)) ago"
        case .inProgress:
            return "\(session.kind.displayName) is in progress"
        case .upcoming:
            return "\(session.kind.displayName) \(countdown(to: session.startsAt))"
        }
    }

    private func nextChronologicalSession(after session: Session, in sessions: [Session]) -> Session? {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else {
            return nil
        }
        return index + 1 < sessions.count ? sessions[index + 1] : nil
    }

    private func countdown(to date: Date) -> String {
        let secs = Int(date.timeIntervalSince(now))
        guard secs > 0 else { return "now" }

        let days = secs / 86_400
        let hours = (secs % 86_400) / 3_600
        let minutes = (secs % 3_600) / 60

        if days >= 1 {
            return "in \(days)d \(hours)h"
        }
        if hours >= 1 {
            return "in \(hours)h \(minutes)m"
        }
        return "in \(minutes)m"
    }

    private func finishedAgo(since date: Date) -> String {
        let secs = max(0, Int(now.timeIntervalSince(date)))
        let hours = secs / 3_600
        let minutes = (secs % 3_600) / 60
        if hours >= 1 {
            return "\(hours)h"
        }
        return "\(minutes)m"
    }

    private func dateRange(from start: Date, to end: Date) -> String {
        let formatter = Date.FormatStyle().day().month(.abbreviated)
        let startText = start.formatted(formatter)
        let endText = end.formatted(formatter)
        return startText == endText ? startText : "\(startText) to \(endText)"
    }

    private func statusColor(_ status: SessionStatus) -> Color {
        switch status {
        case .finished:
            return .green
        case .inProgress:
            return f1Red
        case .upcoming:
            return .blue
        }
    }

    private func refresh() async {
        await store.refresh()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

#Preview {
    ContentView()
        .environmentObject(ScheduleStore())
}
