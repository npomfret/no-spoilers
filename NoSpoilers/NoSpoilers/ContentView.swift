import Combine
import SwiftUI
import NoSpoilersCore

struct ContentView: View {
    @EnvironmentObject private var store: ScheduleStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var now = Date()
    @State private var selectedWeekendIndex: Int = 0
    @State private var weekendsLoaded = false
    @State private var refreshTimer: AnyCancellable?
    @State private var showAbout = false

    var body: some View {
        VStack(spacing: 0) {
            if store.isRefreshing && !weekendsLoaded {
                ScrollView {
                    skeletonView.padding(16)
                }
                .refreshable { await refresh() }
            } else if sortedWeekends.isEmpty {
                ScrollView {
                    unavailableView.padding(16)
                }
                .refreshable { await refresh() }
            } else {
                TabView(selection: $selectedWeekendIndex) {
                    ForEach(sortedWeekends.indices, id: \.self) { index in
                        ScrollView {
                            weekendView(sortedWeekends[index]).padding(16)
                        }
                        .refreshable { await refresh() }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .animation(.easeInOut, value: selectedWeekendIndex)
            }
        }
        .background(backgroundGradient)
        .overlay(alignment: .topTrailing) {
            Button {
                showAbout = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.title3)
                    .foregroundStyle(BrandPalette.secondaryText)
                    .padding(12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(NoSpoilersCore.Strings.About.acknowledgements)
        }
        .sheet(isPresented: $showAbout) {
            AboutView(onDone: { showAbout = false })
        }
        .onAppear {
            if !weekendsLoaded && !sortedWeekends.isEmpty {
                selectedWeekendIndex = initialWeekendIndex()
                weekendsLoaded = true
            }
        }
        .task { await refresh() }
        .onChange(of: store.weekends) { _, _ in
            if !sortedWeekends.isEmpty {
                if !weekendsLoaded {
                    selectedWeekendIndex = initialWeekendIndex()
                    weekendsLoaded = true
                }
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { tick in
            now = tick
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await refresh() }
            setupRefreshTimer()
        }
        .onAppear {
            setupRefreshTimer()
        }
        .onDisappear {
            refreshTimer?.cancel()
        }
    }

    private var backgroundGradient: some View {
        Group {
            if isCurrentWeekendFinished {
                Color(red: 0.96, green: 0.95, blue: 0.94)
                    .ignoresSafeArea()
            } else {
                NoSpoilersBackground()
                    .ignoresSafeArea()
            }
        }
    }

    private var sortedWeekends: [RaceWeekend] {
        store.weekends.sorted { $0.round < $1.round }
    }

    private var isCurrentWeekendFinished: Bool {
        guard !sortedWeekends.isEmpty && selectedWeekendIndex < sortedWeekends.count else {
            return false
        }
        let weekend = sortedWeekends[selectedWeekendIndex]
        return RaceWeekendResolver.firstNonFinishedSession(in: weekend, at: now, confirmedEndDates: store.confirmedEndDates) == nil
    }

    private func weekendView(_ weekend: RaceWeekend) -> some View {
        let sessions = weekend.allSessions
        let nextWeekend = RaceWeekendResolver.nextWeekend(after: weekend, in: store.weekends)
        let isFinished = RaceWeekendResolver.firstNonFinishedSession(in: weekend, at: now, confirmedEndDates: store.confirmedEndDates) == nil

        return VStack(spacing: 16) {
            headerCard(weekend: weekend, sessions: sessions)
            sessionCard(sessions: sessions)
            if !isFinished, let nextWeekend {
                nextWeekendCard(nextWeekend)
            }
        }
    }

    private func headerCard(weekend: RaceWeekend, sessions: [Session]) -> some View {
        let nextSession = RaceWeekendResolver.firstNonFinishedSession(in: weekend, at: now)
        let statusLine = nextSession.map { nextSessionStatus(for: $0, in: sessions) } ?? Strings.Sessions.weekendCompleteStatus()
        let isFinished = nextSession == nil

        return NoSpoilersCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    NoSpoilersWordmark(size: .large)
                    Spacer()
                    FlagImage(countryCode: weekend.countryCode, height: 28)
                }

                Text(weekend.grandPrixName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(BrandPalette.smoke)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                HStack(alignment: .center, spacing: 8) {
                    NoSpoilersRoundPill(Strings.Sessions.roundLabel(weekend.round), isFinished: isFinished)
                    Text(weekend.location)
                        .font(.subheadline)
                        .foregroundStyle(BrandPalette.secondaryText)
                    Spacer()
                    if let first = sessions.first, let last = sessions.last {
                        Text(dateRange(from: first.startsAt, to: last.startsAt))
                            .font(.caption)
                            .foregroundStyle(BrandPalette.tertiaryText)
                    }
                }

                Text(statusLine)
                    .font(.subheadline)
                    .foregroundStyle(BrandPalette.secondaryText)
            }
        }
    }

    private func sessionCard(sessions: [Session]) -> some View {
        NoSpoilersCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(Strings.Sessions.header)
                    .font(.headline)
                    .foregroundStyle(BrandPalette.smoke)

                ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                    let nextSession = index + 1 < sessions.count ? sessions[index + 1] : nil
                    let status = SessionResolver.status(for: session, at: now, nextSession: nextSession)

                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(statusColor(status))
                            .frame(width: 3, height: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.kind.displayName)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(status == .finished ? BrandPalette.finishedGrey : BrandPalette.smoke)
                            Text(session.startsAt.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                                .font(.caption)
                                .foregroundStyle(status == .finished ? BrandPalette.finishedGrey : BrandPalette.secondaryText)
                        }

                        Spacer()

                        statusBadge(for: session, status: status)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(status == .finished ? BrandPalette.finishedGrey.opacity(0.15) : Color.white.opacity(0.65))
                    )
                }
            }
        }
    }

    private func nextWeekendCard(_ weekend: RaceWeekend) -> some View {
        let firstSession = weekend.allSessions.first

        return NoSpoilersCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(Strings.Sessions.comingUp)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BrandPalette.tertiaryText)
                    .textCase(.uppercase)

                HStack(spacing: 10) {
                    FlagImage(countryCode: weekend.countryCode, height: 20)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(weekend.grandPrixName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BrandPalette.smoke)
                        Text(firstSession.map { countdown(to: $0.startsAt) } ?? weekend.location)
                            .font(.caption)
                            .foregroundStyle(BrandPalette.secondaryText)
                    }
                    Spacer()
                    NoSpoilersRoundPill(Strings.Sessions.roundLabel(weekend.round))
                }
            }
        }
    }

    private var skeletonView: some View {
        VStack(spacing: 16) {
            NoSpoilersCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        NoSpoilersWordmark(size: .large)
                        Spacer()
                    }
                    HStack {
                        Spacer(minLength: 0)
                        Text("Loading Grand Prix")
                            .font(.title2.weight(.bold))
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: 8) {
                        NoSpoilersRoundPill("R0")
                        Text("Location")
                            .font(.subheadline)
                        Spacer()
                        Text("1 Jan – 3 Jan")
                            .font(.caption)
                    }
                    Text("Next session in —")
                        .font(.subheadline)
                }
            }
            NoSpoilersCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sessions")
                        .font(.headline)
                    ForEach(0..<5, id: \.self) { _ in
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 2)
                                .frame(width: 3, height: 32)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Free Practice 1")
                                    .font(.body.weight(.semibold))
                                Text("Sat 00:00")
                                    .font(.caption)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.65))
                        )
                    }
                }
            }
        }
        .redacted(reason: .placeholder)
    }

    private var unavailableView: some View {
        NoSpoilersMessageCard(
            title: Text(Strings.Error.unavailableTitle),
            bodyText: Text(Strings.Error.unavailableBody),
            density: .regular
        )
    }

    private var recentlyFinishedWeekend: RaceWeekend? {
        let sorted = store.weekends.sorted { $0.round < $1.round }
        guard let finished = sorted.last(where: {
            !$0.allSessions.isEmpty &&
            RaceWeekendResolver.firstNonFinishedSession(in: $0, at: now, confirmedEndDates: store.confirmedEndDates) == nil
        }) else {
            return nil
        }
        // Only return it if it finished within the last 24 hours
        guard now.timeIntervalSince(endTime(of: finished)) < 24 * 3600 else {
            return nil
        }
        return finished
    }

    private func endTime(of weekend: RaceWeekend) -> Date {
        guard let last = weekend.allSessions.last else { return .distantPast }
        return store.confirmedEndDates[last.id] ?? (last.endsAt + last.kind.gracePeriod)
    }

    @ViewBuilder
    private func statusBadge(for session: Session, status: SessionStatus) -> some View {
        switch status {
        case .finished:
            NoSpoilersStatusBadge(
                text: Strings.Sessions.finishedAgo(finishedAgo(since: session.endsAt)),
                style: .finished
            )
        case .inProgress:
            NoSpoilersStatusBadge(textKey: Strings.Sessions.inProgress, style: .live)
        case .upcoming:
            NoSpoilersStatusBadge(text: countdown(to: session.startsAt), style: .upcoming)
        }
    }

    private func nextSessionStatus(for session: Session, in sessions: [Session]) -> String {
        let nextSession = nextChronologicalSession(after: session, in: sessions)
        switch SessionResolver.status(for: session, at: now, nextSession: nextSession) {
        case .finished:
            return Strings.Sessions.sessionFinished(name: session.kind.displayName, ago: finishedAgo(since: session.endsAt))
        case .inProgress:
            return Strings.Sessions.sessionInProgress(session.kind.displayName)
        case .upcoming:
            return Strings.Sessions.sessionUpcoming(name: session.kind.displayName, countdown: countdown(to: session.startsAt))
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
        guard secs > 0 else { return Strings.Sessions.countdownNow }

        let days = secs / 86_400
        let hours = (secs % 86_400) / 3_600
        let minutes = (secs % 3_600) / 60

        if days >= 1 { return Strings.Sessions.countdownDaysHours(days, hours) }
        if hours >= 1 { return Strings.Sessions.countdownHoursMinutes(hours, minutes) }
        return Strings.Sessions.countdownMinutes(minutes)
    }

    private func finishedAgo(since date: Date) -> String {
        let secs = max(0, Int(now.timeIntervalSince(date)))
        let hours = secs / 3_600
        let minutes = (secs % 3_600) / 60
        if hours >= 1 { return Strings.Sessions.durationHours(hours) }
        return Strings.Sessions.durationMinutes(minutes)
    }

    private func dateRange(from start: Date, to end: Date) -> String {
        let formatter = Date.FormatStyle().day().month(.abbreviated)
        let startText = start.formatted(formatter)
        let endText = end.formatted(formatter)
        return startText == endText ? startText : Strings.Sessions.dateRange(start: startText, end: endText)
    }

    private func statusColor(_ status: SessionStatus) -> Color {
        switch status {
        case .finished:
            return BrandPalette.finishedGrey
        case .inProgress:
            return BrandPalette.signalRed
        case .upcoming:
            return BrandPalette.upcomingAmber
        }
    }

    private func refresh() async {
        await store.refresh()
    }

    private func setupRefreshTimer() {
        refreshTimer?.cancel()
        let interval = refreshInterval()
        refreshTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                Task { await refresh() }
                // Reschedule in case the interval changed (event started/ended)
                setupRefreshTimer()
            }
    }

    private func refreshInterval() -> TimeInterval {
        // Check if any session is currently in progress or upcoming in the next hour
        for weekend in sortedWeekends {
            for session in weekend.allSessions {
                let status = SessionResolver.status(for: session, at: now, nextSession: nil)
                if status == .inProgress {
                    return 5 * 60  // Refresh every 5 minutes during active sessions
                }
                let secondsUntilSession = session.startsAt.timeIntervalSince(now)
                if secondsUntilSession > 0 && secondsUntilSession < 3600 {
                    return 5 * 60  // Refresh every 5 minutes when session starting soon
                }
            }
        }
        return 3600  // Refresh hourly when no events are active
    }

    private func initialWeekendIndex() -> Int {
        let weekends = sortedWeekends
        guard !weekends.isEmpty else { return 0 }

        // 1. Weekend with a current/in-progress session takes priority
        for (index, weekend) in weekends.enumerated() {
            for session in weekend.allSessions {
                if SessionResolver.status(for: session, at: now, nextSession: nil) == .inProgress {
                    return index
                }
            }
        }
        // 2. Most recently finished weekend (if finished less than 24h ago)
        if let recent = recentlyFinishedWeekend,
           let i = weekends.firstIndex(where: { $0.round == recent.round }) {
            return i
        }
        // 3. First weekend with any upcoming sessions
        for (index, weekend) in weekends.enumerated() {
            for session in weekend.allSessions {
                if session.startsAt > now {
                    return index
                }
            }
        }
        // 4. Fallback to last weekend
        return weekends.count - 1
    }
}

#Preview {
    ContentView()
        .environmentObject(ScheduleStore())
}
