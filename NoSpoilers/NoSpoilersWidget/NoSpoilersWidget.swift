import WidgetKit
import SwiftUI
import NoSpoilersCore

private let widgetRed = BrandPalette.signalRed
private let widgetCream = BrandPalette.ivory

private enum WidgetLayout {
    static let outerPadding: CGFloat = 18
    static let sectionSpacing: CGFloat = 14
    static let cardSpacing: CGFloat = 12
    static let cardHorizontalPadding: CGFloat = 14
    static let cardVerticalPadding: CGFloat = 14
}

// MARK: - Shared Mark

struct F1Logo: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 120
        let sy = rect.height / 30
        let t = CGAffineTransform(scaleX: sx, y: sy)
            .translatedBy(x: rect.minX / sx, y: rect.minY / sy)
        var p = Path()

        p.move(to: .init(x: 101.086812, y: 30)); p.addLine(to: .init(x: 101.711812, y: 30))
        p.addLine(to: .init(x: 101.711812, y: 27.106875)); p.addLine(to: .init(x: 101.722437, y: 27.106875))
        p.addLine(to: .init(x: 102.761812, y: 30)); p.addLine(to: .init(x: 103.302437, y: 30))
        p.addLine(to: .init(x: 104.341812, y: 27.106875)); p.addLine(to: .init(x: 104.352437, y: 27.106875))
        p.addLine(to: .init(x: 104.352437, y: 30)); p.addLine(to: .init(x: 104.977437, y: 30))
        p.addLine(to: .init(x: 104.977437, y: 26.25125)); p.addLine(to: .init(x: 104.063687, y: 26.25125))
        p.addLine(to: .init(x: 103.055562, y: 29.18625)); p.addLine(to: .init(x: 103.044937, y: 29.18625))
        p.addLine(to: .init(x: 102.011187, y: 26.25125)); p.addLine(to: .init(x: 101.086812, y: 26.25125))
        p.closeSubpath()

        p.move(to: .init(x: 97.6274375, y: 26.818125)); p.addLine(to: .init(x: 98.8136875, y: 26.818125))
        p.addLine(to: .init(x: 98.8136875, y: 30)); p.addLine(to: .init(x: 99.4699375, y: 30))
        p.addLine(to: .init(x: 99.4699375, y: 26.818125)); p.addLine(to: .init(x: 100.661812, y: 26.818125))
        p.addLine(to: .init(x: 100.661812, y: 26.25125)); p.addLine(to: .init(x: 97.6274375, y: 26.25125))
        p.closeSubpath()

        p.move(to: .init(x: 89.9999375, y: 30)); p.addLine(to: .init(x: 119.999937, y: 0))
        p.addLine(to: .init(x: 101.943687, y: 0)); p.addLine(to: .init(x: 71.9443125, y: 30))
        p.closeSubpath()

        p.move(to: .init(x: 85.6986875, y: 13.065)); p.addLine(to: .init(x: 49.3818125, y: 13.065))
        p.addCurve(to: .init(x: 31.6361875, y: 18.3925),
                   control1: .init(x: 38.3136875, y: 13.065), control2: .init(x: 36.3768125, y: 13.651875))
        p.addCurve(to: .init(x: 20.0005625, y: 30),
                   control1: .init(x: 27.2024375, y: 22.82625), control2: .init(x: 20.0005625, y: 30))
        p.addLine(to: .init(x: 35.7324375, y: 30)); p.addLine(to: .init(x: 39.4855625, y: 26.246875))
        p.addCurve(to: .init(x: 48.4068125, y: 23.52375),
                   control1: .init(x: 41.9530625, y: 23.779375), control2: .init(x: 43.2255625, y: 23.52375))
        p.addLine(to: .init(x: 75.2405625, y: 23.52375))
        p.closeSubpath()

        p.move(to: .init(x: 31.1518125, y: 16.253125))
        p.addCurve(to: .init(x: 16.9130625, y: 30),
                   control1: .init(x: 27.8774375, y: 19.3425), control2: .init(x: 20.7530625, y: 26.263125))
        p.addLine(to: .init(x: 0, y: 30))
        p.addCurve(to: .init(x: 21.0849375, y: 9.0725),
                   control1: .init(x: 0, y: 30), control2: .init(x: 13.5524375, y: 16.486875))
        p.addCurve(to: .init(x: 46.9486875, y: 0),
                   control1: .init(x: 28.8455625, y: 1.685), control2: .init(x: 32.7143125, y: 0))
        p.addLine(to: .init(x: 98.7643125, y: 0)); p.addLine(to: .init(x: 87.5449375, y: 11.21875))
        p.addLine(to: .init(x: 48.0011875, y: 11.21875))
        p.addCurve(to: .init(x: 31.1518125, y: 16.253125),
                   control1: .init(x: 37.9993125, y: 11.21875), control2: .init(x: 35.7518125, y: 11.911875))
        p.closeSubpath()

        return p.applying(t)
    }
}

// MARK: - Entry

struct NoSpoilersEntry: TimelineEntry {
    let date: Date
    let weekend: RaceWeekend?
    let sessions: [SessionViewModel]
    let offSeasonNextRace: SessionViewModel?
    let nextWeekend: UpcomingWeekendViewModel?
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
    let flag: String
    let name: String
    let countdown: String
}

enum SessionState {
    case finished(ago: String)         // "2h ago"
    case live
    case upcoming(countdown: String)   // "in 4h 23m"
    case offSeason(daysUntil: String)  // "in 12 days"
}

// MARK: - Helpers

private func countdownString(to date: Date, from now: Date) -> String {
    let secs = max(0, Int(date.timeIntervalSince(now)))
    let days = secs / 86_400
    let hours = (secs % 86_400) / 3600
    let minutes = (secs % 3600) / 60

    if days >= 1 { return "in \(days)d \(hours)h" }
    if hours >= 1 { return "in \(hours)h \(minutes)m" }
    return "in \(minutes)m"
}

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
        return .upcoming(countdown: countdownString(to: session.startsAt, from: now))
    }
}

private func makeEntry(at now: Date) -> NoSpoilersEntry {
    let weekends = (try? ScheduleCache().load(for: NoSpoilersConfig.appGroupID)) ?? []
    let confirmedEndDates = SessionEndConfirmer.loadStoredDates(appGroupID: NoSpoilersConfig.appGroupID)

    guard let weekend = RaceWeekendResolver.firstActiveWeekend(in: weekends, at: now, confirmedEndDates: confirmedEndDates),
          let firstActiveSession = RaceWeekendResolver.firstNonFinishedSession(in: weekend, at: now, confirmedEndDates: confirmedEndDates)
    else {
        return NoSpoilersEntry(date: now, weekend: nil, sessions: [], offSeasonNextRace: nil, nextWeekend: nil)
    }

    let sorted = weekend.allSessions
    if firstActiveSession.startsAt.timeIntervalSince(now) > 7 * 86_400 {
        let days = Int(firstActiveSession.startsAt.timeIntervalSince(now) / 86_400)
        let vm = SessionViewModel(
            id: firstActiveSession.id,
            name: weekend.grandPrixName,
            shortName: "Next",
            state: .offSeason(daysUntil: "in \(days) days")
        )
        return NoSpoilersEntry(date: now, weekend: nil, sessions: [], offSeasonNextRace: vm, nextWeekend: nil)
    }

    let sessionVMs = sorted.indices.map { i in
        let s = sorted[i]
        let next = i + 1 < sorted.count ? sorted[i + 1] : nil
        return SessionViewModel(
            id: s.id,
            name: s.kind.displayName,
            shortName: s.kind.shortName,
            state: sessionState(for: s, nextSession: next, at: now, confirmedEndDates: confirmedEndDates)
        )
    }
    let nextWeekend = RaceWeekendResolver.nextWeekend(after: weekend, in: weekends).flatMap { weekend -> UpcomingWeekendViewModel? in
        guard let firstSession = weekend.allSessions.first else { return nil }
        return UpcomingWeekendViewModel(
            round: weekend.round,
            flag: weekend.countryFlag,
            name: weekend.grandPrixName,
            countdown: countdownString(to: firstSession.startsAt, from: now)
        )
    }
    return NoSpoilersEntry(date: now, weekend: weekend, sessions: sessionVMs, offSeasonNextRace: nil, nextWeekend: nextWeekend)
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
        NoSpoilersEntry(date: Date(), weekend: nil, sessions: [], offSeasonNextRace: nil, nextWeekend: nil)
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
        } else {
            noDataView
        }
    }

    @ViewBuilder
    private func offSeasonView(_ next: SessionViewModel) -> some View {
        VStack(alignment: .leading, spacing: WidgetLayout.sectionSpacing) {
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
                    .foregroundStyle(BrandPalette.secondaryText)
            }
            Text("The next race weekend will appear here as soon as it gets close enough to matter.")
                .font(.caption2)
                .foregroundStyle(BrandPalette.tertiaryText)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(WidgetLayout.outerPadding)
    }

    @ViewBuilder
    private var smallView: some View {
        let next = entry.sessions.first { if case .finished = $0.state { return false }; return true }
                   ?? entry.sessions.first
        VStack(alignment: .leading, spacing: WidgetLayout.sectionSpacing) {
            F1Logo()
                .fill(widgetRed)
                .frame(width: 68, height: 17)

            Spacer(minLength: 0)

            if let s = next {
                Text(s.shortName)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                smallStateLabel(s.state)
                if let weekend = entry.weekend {
                    Text("\(weekend.location) - \(weekend.countryName)")
                        .font(.caption2)
                        .foregroundStyle(BrandPalette.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(WidgetLayout.outerPadding)
    }

    @ViewBuilder
    private var mediumView: some View {
        let primary = entry.sessions.first { if case .finished = $0.state { return false }; return true }
            ?? entry.sessions.last
        let recentFinished = entry.sessions.last { session in
            if case .finished = session.state { return true }
            return false
        }

        VStack(alignment: .leading, spacing: WidgetLayout.sectionSpacing) {
            if let weekend = entry.weekend {
                mediumHeader(weekend)
            }

            HStack(alignment: .top, spacing: WidgetLayout.cardSpacing) {
                if let recentFinished, recentFinished.id != primary?.id {
                    mediumSessionCard(
                        session: recentFinished,
                        accent: BrandPalette.successGreen,
                        emphasize: false
                    )
                } else if let weekend = entry.weekend {
                    mediumWeekendCard(weekend)
                } else if let nextWeekend = entry.nextWeekend {
                    mediumUpcomingCard(nextWeekend)
                }

                if let primary {
                    mediumSessionCard(
                        session: primary,
                        accent: accentColor(for: primary.state),
                        emphasize: true
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(WidgetLayout.outerPadding)
    }

    @ViewBuilder
    private var largeView: some View {
        let visibleSessions = Array(entry.sessions.prefix(5))
        let hiddenCount = max(0, entry.sessions.count - visibleSessions.count)

        VStack(alignment: .leading, spacing: WidgetLayout.sectionSpacing) {
            if let weekend = entry.weekend {
                fullHeader(weekend)
            }
            VStack(spacing: 8) {
                ForEach(visibleSessions) { session in
                    sessionRow(session)
                }
            }
            if hiddenCount > 0 {
                Text("+\(hiddenCount) more session\(hiddenCount == 1 ? "" : "s")")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BrandPalette.secondaryText)
                    .padding(.horizontal, 4)
            }
            Spacer(minLength: 0)
            if let nextWeekend = entry.nextWeekend {
                Divider()
                upcomingFooter(nextWeekend)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(WidgetLayout.outerPadding)
    }

    @ViewBuilder
    private var noDataView: some View {
        VStack(spacing: WidgetLayout.sectionSpacing) {
            Image(systemName: "flag.checkered.2.crossed")
                .font(.system(size: 28))
                .foregroundStyle(widgetRed)
            Text("Schedule unavailable")
                .font(.headline)
            Text("Open the app to refresh the shared schedule cache.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(BrandPalette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(WidgetLayout.outerPadding)
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
                    .foregroundStyle(BrandPalette.secondaryText)
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
                .foregroundStyle(BrandPalette.tertiaryText)
        }
    }

    private func mediumHeader(_ weekend: RaceWeekend) -> some View {
        HStack(alignment: .center, spacing: 10) {
            F1Logo()
                .fill(widgetRed)
                .frame(width: 36, height: 9)

            VStack(alignment: .leading, spacing: 2) {
                Text(weekend.grandPrixName)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                Text("\(weekend.location), \(weekend.countryName)")
                    .font(.caption2)
                    .foregroundStyle(BrandPalette.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Text(weekend.countryFlag)
                .font(.headline)

            Text("R\(weekend.round)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(widgetRed)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(BrandPalette.blush.opacity(0.7))
                .clipShape(Capsule())
        }
    }

    private func mediumSessionCard(session: SessionViewModel, accent: Color, emphasize: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accent)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Spacer(minLength: 0)
                    if case .live = session.state {
                        Circle()
                            .fill(accent)
                            .frame(width: 7, height: 7)
                    }
                }

                Text(session.shortName)
                    .font(.system(size: emphasize ? 25 : 22, weight: .black, design: .rounded))
                    .foregroundStyle(BrandPalette.smoke)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if shouldShowSecondaryName(for: session) {
                    Text(session.name)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(BrandPalette.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                mediumStatusLine(session.state, accent: accent, emphasize: emphasize)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
        .padding(.horizontal, WidgetLayout.cardHorizontalPadding)
        .padding(.vertical, WidgetLayout.cardVerticalPadding)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(emphasize ? 0.82 : 0.74))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(BrandPalette.mistGrey.opacity(0.55), lineWidth: 1)
        )
    }

    private func mediumWeekendCard(_ weekend: RaceWeekend) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekend")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(BrandPalette.secondaryText)
                .textCase(.uppercase)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(weekend.countryFlag)
                    .font(.headline)
                Text("R\(weekend.round)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(BrandPalette.smoke)
            }

            Text("\(weekend.location), \(weekend.countryName)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(BrandPalette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(sessionDateRange(for: weekend))
                .font(.caption2)
                .foregroundStyle(BrandPalette.tertiaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
        .padding(.horizontal, WidgetLayout.cardHorizontalPadding)
        .padding(.vertical, WidgetLayout.cardVerticalPadding)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.74))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(BrandPalette.mistGrey.opacity(0.55), lineWidth: 1)
        )
    }

    private func mediumUpcomingCard(_ weekend: UpcomingWeekendViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Coming up")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(widgetRed)
                .textCase(.uppercase)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(weekend.flag)
                    .font(.headline)
                Text("R\(weekend.round)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(BrandPalette.smoke)
            }

            Text(weekend.name)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(BrandPalette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(weekend.countdown)
                .font(.caption2)
                .foregroundStyle(BrandPalette.tertiaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
        .padding(.horizontal, WidgetLayout.cardHorizontalPadding)
        .padding(.vertical, WidgetLayout.cardVerticalPadding)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.74))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(BrandPalette.mistGrey.opacity(0.55), lineWidth: 1)
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

    private func upcomingFooter(_ weekend: UpcomingWeekendViewModel) -> some View {
        HStack(spacing: 10) {
            Text(weekend.flag)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Coming up...")
                    .font(.caption2)
                    .foregroundStyle(BrandPalette.secondaryText)
                Text(weekend.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(weekend.countdown)
                    .font(.caption2)
                    .foregroundStyle(BrandPalette.tertiaryText)
            }
            Spacer()
            Text("R\(weekend.round)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(widgetRed)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(widgetRed.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    private func accentColor(for state: SessionState) -> Color {
        switch state {
        case .finished:
            return BrandPalette.successGreen.opacity(0.75)
        case .live:
            return widgetRed
        case .upcoming, .offSeason:
            return BrandPalette.deepMaroon.opacity(0.45)
        }
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
    private func mediumStatusLine(_ state: SessionState, accent: Color, emphasize: Bool) -> some View {
        switch state {
        case .finished(let ago):
            HStack(spacing: 4) {
                Text("Finished")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BrandPalette.successGreen)
                Text(ago)
                    .font(.caption2)
                    .foregroundStyle(BrandPalette.secondaryText)
            }
            .lineLimit(1)
        case .live:
            Text("In Progress")
                .font((emphasize ? Font.caption : .caption2).weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, emphasize ? 10 : 8)
                .padding(.vertical, 4)
                .background(accent)
                .clipShape(Capsule())
        case .upcoming(let countdown):
            Text(countdown)
                .font((emphasize ? Font.caption : .caption2).weight(.semibold))
                .foregroundStyle(BrandPalette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        case .offSeason(let daysUntil):
            Text(daysUntil)
                .font((emphasize ? Font.caption : .caption2).weight(.semibold))
                .foregroundStyle(BrandPalette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    @ViewBuilder
    private func stateLabel(_ state: SessionState) -> some View {
        switch state {
        case .finished(let ago):
            VStack(alignment: .trailing, spacing: 1) {
                Text("Finished").font(.caption2).foregroundStyle(BrandPalette.successGreen)
                Text(ago).font(.caption2).foregroundStyle(BrandPalette.secondaryText)
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
                .foregroundStyle(BrandPalette.secondaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(BrandPalette.blush.opacity(0.7))
                .clipShape(Capsule())
        case .offSeason(let d):
            Text(d)
                .font(.caption2)
                .foregroundStyle(BrandPalette.secondaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(BrandPalette.blush.opacity(0.7))
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
                    .foregroundStyle(BrandPalette.successGreen)
                Text(ago)
                    .font(.caption2)
                    .foregroundStyle(BrandPalette.secondaryText)
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
                .foregroundStyle(BrandPalette.secondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(BrandPalette.blush.opacity(0.7))
                .clipShape(Capsule())
        case .offSeason(let d):
            Text(d)
                .font(.caption)
                .foregroundStyle(BrandPalette.secondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(BrandPalette.blush.opacity(0.7))
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private func smallStateLabel(_ state: SessionState) -> some View {
        switch state {
        case .finished(let ago):
            VStack(alignment: .leading, spacing: 2) {
                Text("Finished")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandPalette.successGreen)
                Text(ago)
                    .font(.caption)
                    .foregroundStyle(BrandPalette.secondaryText)
            }
        case .live:
            Text("Now")
                .font(.headline.weight(.bold))
                .foregroundStyle(widgetRed)
        case .upcoming(let c):
            Text(c)
                .font(.headline.weight(.semibold))
                .foregroundStyle(BrandPalette.secondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        case .offSeason(let d):
            Text(d)
                .font(.headline.weight(.semibold))
                .foregroundStyle(BrandPalette.secondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
    }

    @ViewBuilder
    private func mediumStateBadge(_ state: SessionState, emphasize: Bool) -> some View {
        switch state {
        case .finished(let ago):
            VStack(alignment: .leading, spacing: 1) {
                Text("Finished")
                    .font((emphasize ? Font.caption : .caption2).weight(.semibold))
                    .foregroundStyle(BrandPalette.successGreen)
                Text(ago)
                    .font(emphasize ? .caption : .caption2)
                    .foregroundStyle(BrandPalette.secondaryText)
            }
        case .live:
            Text("In Progress")
                .font((emphasize ? Font.caption : .caption2).weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, emphasize ? 10 : 8)
                .padding(.vertical, emphasize ? 5 : 4)
                .background(widgetRed)
                .clipShape(Capsule())
        case .upcoming(let countdown):
            Text(countdown)
                .font((emphasize ? Font.caption : .caption2).weight(.semibold))
                .foregroundStyle(BrandPalette.secondaryText)
                .lineLimit(2)
                .padding(.horizontal, emphasize ? 10 : 8)
                .padding(.vertical, emphasize ? 5 : 4)
                .background(BrandPalette.blush.opacity(0.7))
                .clipShape(Capsule())
        case .offSeason(let daysUntil):
            Text(daysUntil)
                .font((emphasize ? Font.caption : .caption2).weight(.semibold))
                .foregroundStyle(BrandPalette.secondaryText)
                .lineLimit(2)
                .padding(.horizontal, emphasize ? 10 : 8)
                .padding(.vertical, emphasize ? 5 : 4)
                .background(BrandPalette.blush.opacity(0.7))
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
                            BrandPalette.ivory,
                            BrandPalette.blush.opacity(0.45),
                            Color.white
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("No Spoilers")
        .description("F1 race weekend sessions — no results.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
