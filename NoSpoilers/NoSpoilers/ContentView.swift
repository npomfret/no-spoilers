import Combine
import SwiftUI
import WidgetKit
import NoSpoilersCore

private let offSeasonThreshold: TimeInterval = 7 * 86_400

struct ContentView: View {
    @EnvironmentObject private var store: ScheduleStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var now = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    appHeader
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
                BrandPalette.ivory,
                BrandPalette.blush.opacity(0.72),
                Color.white
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var appHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("No Spoilers")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(BrandPalette.smoke)

            Spacer()

            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.8), lineWidth: 1)
                )
                .shadow(color: BrandPalette.deepMaroon.opacity(0.12), radius: 10, x: 0, y: 6)
        }
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
            HStack(alignment: .center, spacing: 12) {
                F1Logo()
                    .fill(BrandPalette.signalRed)
                    .frame(width: 72, height: 18)
                Spacer()
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Round \(weekend.round)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(BrandPalette.signalRed)
                    Text(weekend.grandPrixName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(BrandPalette.smoke)
                    Text(weekend.location)
                        .font(.subheadline)
                        .foregroundStyle(BrandPalette.secondaryText)
                }
                Spacer()
                Text(weekend.countryFlag)
                    .font(.system(size: 40))
            }

            Text(statusLine)
                .font(.subheadline)
                .foregroundStyle(BrandPalette.secondaryText)

            if let first = sessions.first, let last = sessions.last {
                Text(dateRange(from: first.startsAt, to: last.startsAt))
                    .font(.caption)
                    .foregroundStyle(BrandPalette.tertiaryText)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(BrandPalette.mistGrey.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: BrandPalette.deepMaroon.opacity(0.08), radius: 20, x: 0, y: 12)
    }

    private func sessionCard(sessions: [Session]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sessions")
                .font(.headline)
                .foregroundStyle(BrandPalette.smoke)

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
                            .foregroundStyle(BrandPalette.smoke)
                        Text(session.startsAt.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                            .font(.caption)
                            .foregroundStyle(BrandPalette.secondaryText)
                    }

                    Spacer()

                    statusBadge(for: session, status: status)
                }

                if session.id != sessions.last?.id {
                    Divider()
                        .overlay(BrandPalette.mistGrey.opacity(0.6))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(BrandPalette.mistGrey.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: BrandPalette.deepMaroon.opacity(0.08), radius: 18, x: 0, y: 10)
    }

    private func nextWeekendCard(_ weekend: RaceWeekend) -> some View {
        let firstSession = weekend.allSessions.first

        return VStack(alignment: .leading, spacing: 8) {
            Text("Coming up...")
                .font(.headline)
                .foregroundStyle(BrandPalette.smoke)
            HStack(spacing: 12) {
                Text(weekend.countryFlag)
                    .font(.title)
                VStack(alignment: .leading, spacing: 4) {
                    Text(weekend.grandPrixName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandPalette.smoke)
                    if let firstSession {
                        Text(countdown(to: firstSession.startsAt))
                            .font(.caption)
                            .foregroundStyle(BrandPalette.secondaryText)
                    } else {
                        Text(weekend.location)
                            .font(.caption)
                            .foregroundStyle(BrandPalette.secondaryText)
                    }
                }
                Spacer()
                Text("R\(weekend.round)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandPalette.signalRed)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(BrandPalette.blush.opacity(0.7), in: Capsule())
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(BrandPalette.mistGrey.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: BrandPalette.deepMaroon.opacity(0.08), radius: 18, x: 0, y: 10)
    }

    private func offSeasonView(weekend: RaceWeekend, session: Session) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Off-season")
                .font(.headline)
                .foregroundStyle(BrandPalette.signalRed)
            Text(weekend.grandPrixName)
                .font(.title2.weight(.bold))
                .foregroundStyle(BrandPalette.smoke)
            Text("Next session \(countdown(to: session.startsAt))")
                .font(.subheadline)
                .foregroundStyle(BrandPalette.secondaryText)
            Text(weekend.location)
                .font(.caption)
                .foregroundStyle(BrandPalette.tertiaryText)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(BrandPalette.mistGrey.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: BrandPalette.deepMaroon.opacity(0.08), radius: 20, x: 0, y: 12)
    }

    private var unavailableView: some View {
        VStack(spacing: 12) {
            Image(systemName: "flag.checkered.2.crossed")
                .font(.system(size: 34))
                .foregroundStyle(BrandPalette.signalRed)
            Text("Schedule unavailable")
                .font(.headline)
                .foregroundStyle(BrandPalette.smoke)
            Text("Pull to refresh or open the app again to update the shared widget cache.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(BrandPalette.secondaryText)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(BrandPalette.mistGrey.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: BrandPalette.deepMaroon.opacity(0.08), radius: 18, x: 0, y: 10)
    }

    @ViewBuilder
    private func statusBadge(for session: Session, status: SessionStatus) -> some View {
        switch status {
        case .finished:
            Text("Finished \(finishedAgo(since: session.endsAt))")
                .font(.caption.weight(.medium))
                .foregroundStyle(BrandPalette.successGreen)
        case .inProgress:
            Text("In Progress")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(BrandPalette.signalRed, in: Capsule())
        case .upcoming:
            Text(countdown(to: session.startsAt))
                .font(.caption.weight(.medium))
                .foregroundStyle(BrandPalette.secondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(BrandPalette.blush.opacity(0.55), in: Capsule())
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
            return BrandPalette.successGreen
        case .inProgress:
            return BrandPalette.signalRed
        case .upcoming:
            return BrandPalette.deepMaroon.opacity(0.55)
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
