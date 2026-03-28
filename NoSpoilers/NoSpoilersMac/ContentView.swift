import SwiftUI
import NoSpoilersCore

struct WeekendPopoverView: View {
    @ObservedObject var store: ScheduleStore

    var body: some View {
        let now = Date()
        let current = store.weekends
            .sorted { $0.round < $1.round }
            .first(where: { $0.allSessions.contains { $0.endsAt >= now } })

        if let weekend = current {
            weekendView(weekend, now: now)
        } else {
            noDataView
        }
    }

    private func weekendView(_ weekend: RaceWeekend, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(weekend.grandPrixName).font(.headline)
            Text(weekend.location).font(.caption).foregroundStyle(.secondary)
            Divider()
            ForEach(weekend.allSessions) { session in
                HStack {
                    Text(session.kind.displayName).font(.body)
                    Spacer()
                    stateLabel(for: session, at: now)
                }
            }
        }
        .padding()
    }

    private var noDataView: some View {
        Text("Schedule unavailable\nOpen app to refresh")
            .font(.caption).multilineTextAlignment(.center).foregroundStyle(.secondary)
            .padding()
    }

    @ViewBuilder
    private func stateLabel(for session: Session, at now: Date) -> some View {
        if session.endsAt < now {
            let secs = Int(now.timeIntervalSince(session.endsAt))
            let h = secs / 3600
            let m = (secs % 3600) / 60
            let ago = h > 0 ? "\(h)h ago" : "\(m)m ago"
            VStack(alignment: .trailing, spacing: 1) {
                Text("Finished").font(.callout).foregroundStyle(.green)
                Text(ago).font(.caption2).foregroundStyle(.secondary)
            }
        } else if session.startsAt <= now {
            Text("Now").font(.callout).foregroundStyle(.orange)
        } else {
            let secs = Int(session.startsAt.timeIntervalSince(now))
            let h = secs / 3600
            let m = (secs % 3600) / 60
            Text(h > 0 ? "in \(h)h \(m)m" : "in \(m)m").font(.callout).foregroundStyle(.secondary)
        }
    }
}
