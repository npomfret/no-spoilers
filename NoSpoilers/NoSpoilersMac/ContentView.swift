import SwiftUI
import Combine
import NoSpoilersCore

private let f1Red = Color(red: 0.93, green: 0, blue: 0)

struct WeekendPopoverView: View {
    @ObservedObject var store: ScheduleStore
    @State private var now: Date = Date()

    var body: some View {
        let now = self.now
        let current = store.weekends
            .sorted { $0.round < $1.round }
            .first(where: { $0.allSessions.contains { $0.endsAt >= now } })

        Group {
            if let weekend = current {
                weekendView(weekend, now: now)
            } else {
                noDataView
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { tick in
            self.now = tick
        }
    }

    private func weekendView(_ weekend: RaceWeekend, now: Date) -> some View {
        let sorted = store.weekends.sorted { $0.round < $1.round }
        let nextWeekend = sorted.first(where: { $0.round > weekend.round })
        return VStack(spacing: 0) {
            header(weekend)
            Divider()
            sessionList(weekend, now: now)
            if let next = nextWeekend {
                Divider()
                nextRoundFooter(next, now: now)
            }
        }
    }

    private func header(_ weekend: RaceWeekend) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Row 1: logo · GP name (centered) · flag
            HStack(alignment: .center, spacing: 10) {
                F1Logo()
                    .fill(f1Red)
                    .frame(width: 48, height: 12)
                Spacer()
                Text(weekend.grandPrixName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                Spacer()
                Text(weekend.countryFlag)
                    .font(.system(size: 26))
            }
            // Row 2: round pill · location
            HStack(alignment: .center, spacing: 6) {
                Text("R\(weekend.round)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(f1Red)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(f1Red.opacity(0.1))
                    .clipShape(Capsule())
                Text(weekend.location)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func sessionList(_ weekend: RaceWeekend, now: Date) -> some View {
        VStack(spacing: 1) {
            ForEach(weekend.allSessions) { session in
                sessionRow(session, at: now)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func sessionRow(_ session: Session, at now: Date) -> some View {
        let done = session.endsAt < now
        let live = !done && session.startsAt <= now
        return HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(done ? Color.green.opacity(0.6) : live ? f1Red : Color.accentColor.opacity(0.6))
                .frame(width: 3, height: 28)
            Text(session.kind.displayName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(done ? Color.green : .primary)
                .frame(minWidth: 100, alignment: .leading)
            Spacer()
            statusBadge(for: session, at: now)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func statusBadge(for session: Session, at now: Date) -> some View {
        if session.endsAt < now {
            let secs = Int(now.timeIntervalSince(session.endsAt))
            let h = secs / 3600
            let m = (secs % 3600) / 60
            Text("Finished \(h > 0 ? "\(h)h" : "\(m)m") ago")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if session.startsAt <= now {
            HStack(spacing: 3) {
                Circle().fill(Color.white).frame(width: 5, height: 5)
                Text("LIVE")
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(f1Red)
            .clipShape(Capsule())
        } else {
            Text(countdown(to: session.startsAt, from: now))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.08))
                .clipShape(Capsule())
        }
    }

    private func countdown(to date: Date, from now: Date) -> String {
        let secs = Int(date.timeIntervalSince(now))
        guard secs > 0 else { return "0s" }
        let d = secs / 86_400
        let h = (secs % 86_400) / 3600
        let m = (secs % 3600) / 60
        let s = secs % 60
        if d >= 1 { return "\(d)d \(h)h \(m)m" }
        if h >= 1 { return "\(h)h \(m)m \(s)s" }
        if m >= 1 { return "\(m)m \(s)s" }
        return "\(s)s"
    }

    private func nextRoundFooter(_ weekend: RaceWeekend, now: Date) -> some View {
        let raceDate = weekend.sessions[.race] ?? weekend.sessions[.sprint]
        let firstSession = weekend.allSessions.first
        return HStack(spacing: 8) {
            Text(weekend.countryFlag).font(.body)
            VStack(alignment: .leading, spacing: 1) {
                Text(weekend.grandPrixName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    if let date = raceDate {
                        Text(date.formatted(.dateTime.day().month(.abbreviated)))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    if let session = firstSession {
                        Text("· \(countdown(to: session.startsAt, from: now))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()
            Text("R\(weekend.round)")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(f1Red)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(f1Red.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var noDataView: some View {
        VStack(spacing: 10) {
            Text("🏁")
                .font(.system(size: 36))
            Text("Off season")
                .font(.headline)
            Text("No upcoming sessions found")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}
