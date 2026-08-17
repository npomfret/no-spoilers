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
    @State private var widgetInstall: WidgetInstallStatus = .unknown

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // Swiping is otherwise the only way between 23 weekends, with page dots as the
                // only indication of where you are. If a swipe does not take — the thing this
                // screen was reported for — there is no other route back to the weekend that
                // matters. Only shown when you have actually navigated away from it.
                if let currentIndex = currentWeekendIndex, currentIndex != selectedWeekendIndex {
                    Button {
                        selectedWeekendIndex = currentIndex
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                            Text(Strings.Navigation.currentWeekend)
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(BrandPalette.secondaryText)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Strings.Navigation.jumpToCurrentWeekend)
                }
                Spacer()
                Button {
                    showAbout = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundStyle(BrandPalette.secondaryText)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(NoSpoilersCore.Strings.About.acknowledgements)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)

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
                // No `.refreshable` on these pages, deliberately. Pull-to-refresh installs a
                // gesture on the inner ScrollView that competes with the page view's horizontal
                // pan, so any swipe with a downward component could be claimed by refresh instead
                // of paging — worst at the top of the page, which is where a swipe usually starts.
                // Refresh is automatic: `.task`, `scenePhase == .active`, and `setupRefreshTimer`.
                // The skeleton and unavailable views keep theirs; they are outside the pager.
                //
                // No `.animation(_:value:)` either. Paging runs its own interactive transition;
                // adding a second implicit animation over the whole subtree fights it.
                TabView(selection: $selectedWeekendIndex) {
                    ForEach(sortedWeekends.indices, id: \.self) { index in
                        ScrollView {
                            weekendView(sortedWeekends[index]).padding(16)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            }
        }
        .background(backgroundGradient)
        .sheet(isPresented: $showAbout) {
            AboutView(onDone: { showAbout = false })
        }
        .onAppear {
            homeSelectionIfNeeded()
            setupRefreshTimer()
        }
        .task { await refresh() }
        .task { widgetInstall = await WidgetInstallStatus.current() }
        .onChange(of: store.weekends) { _, _ in
            homeSelectionIfNeeded()
        }
        // `now` is read by every session row on every page, so writing it invalidates the whole
        // TabView — mid-swipe included. Nothing on this screen renders sub-minute granularity
        // (`countdown` and `finishedAgo` both stop at minutes), so poll at 1 Hz but only publish
        // when the minute rolls over: one invalidation a minute instead of sixty, and status
        // transitions still land within a second of the boundary they belong to.
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { tick in
            if minuteIndex(of: tick) != minuteIndex(of: now) { now = tick }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            now = Date()
            Task { await refresh() }
            // Re-asked on every activation because the answer is a snapshot, and the single most
            // likely thing to have happened while we were backgrounded is the user following the
            // instructions on this very card. Coming back to it still telling them to do what they
            // just did would be worse than never showing it.
            Task { widgetInstall = await WidgetInstallStatus.current() }
            setupRefreshTimer()
        }
        .onDisappear {
            refreshTimer?.cancel()
        }
    }

    /// Picks the page to show on first load, and keeps the selection valid afterwards.
    ///
    /// The selection used to be chosen once, latched, and never looked at again: if the schedule
    /// shrank — a shorter season, or a cache that loaded fewer weekends than the network did —
    /// `selectedWeekendIndex` could name a page no `.tag` matched, leaving the pager on nothing.
    private func homeSelectionIfNeeded() {
        guard !sortedWeekends.isEmpty else { return }
        if !weekendsLoaded {
            selectedWeekendIndex = initialWeekendIndex()
            weekendsLoaded = true
            return
        }
        selectedWeekendIndex = min(selectedWeekendIndex, sortedWeekends.count - 1)
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

    /// The page the app would open on right now — live weekend, else one that finished in the last
    /// day, else the next one up. Nil when there is nothing to show.
    private var currentWeekendIndex: Int? {
        sortedWeekends.isEmpty ? nil : initialWeekendIndex()
    }

    /// Wall-clock minute a date falls in. Used to decide whether republishing `now` could change
    /// anything on screen.
    private func minuteIndex(of date: Date) -> Int {
        Int(date.timeIntervalSinceReferenceDate / 60)
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
        // Resolved once and handed down. The header used to resolve it again for itself, and did
        // so without the confirmed end dates, so during an overrun the header could call the
        // weekend complete while the body below it still showed a live session.
        let nextSession = RaceWeekendResolver.firstNonFinishedSession(
            in: weekend,
            at: now,
            confirmedEndDates: store.confirmedEndDates
        )

        return VStack(spacing: 16) {
            // First, because a user without the widget has not finished setting the app up and
            // that is the most useful thing on the screen for them. It scrolls away like any other
            // card, and it is gone for good the moment they act.
            if widgetInstall.shouldPromptToInstall {
                WidgetInstallCard()
            }
            headerCard(weekend: weekend, sessions: sessions, nextSession: nextSession)
            sessionCard(sessions: sessions)
            if nextSession != nil, let nextWeekend {
                nextWeekendCard(nextWeekend)
            }
        }
    }

    private func headerCard(weekend: RaceWeekend, sessions: [Session], nextSession: Session?) -> some View {
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
                    NoSpoilersRoundPill(NoSpoilersCore.Strings.Schedule.roundLabel(weekend.round), isFinished: isFinished)
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
                    let status = SessionResolver.status(
                        for: session,
                        at: now,
                        nextSession: nextSession,
                        confirmedEndAt: store.confirmedEndDates[session.id]
                    )

                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(statusColor(status))
                            .frame(width: 3, height: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.kind.displayName)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(status == .finished ? BrandPalette.finishedGrey : BrandPalette.smoke)
                            Text(NoSpoilersCore.Strings.Schedule.sessionDateTime(session.startsAt))
                                .font(.caption)
                                .foregroundStyle(status == .finished ? BrandPalette.finishedGrey : BrandPalette.secondaryText)
                        }

                        Spacer()

                        statusBadge(for: session, nextSession: nextSession, status: status)
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
                Text(NoSpoilersCore.Strings.Schedule.comingUp)
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
                    NoSpoilersRoundPill(NoSpoilersCore.Strings.Schedule.roundLabel(weekend.round))
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
            title: Text(NoSpoilersCore.Strings.Schedule.unavailableTitle),
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
        let endedAt = RaceWeekendResolver.effectiveEndDate(of: finished, confirmedEndDates: store.confirmedEndDates)
        guard now.timeIntervalSince(endedAt) < 24 * 3600 else {
            return nil
        }
        return finished
    }

    @ViewBuilder
    private func statusBadge(for session: Session, nextSession: Session?, status: SessionStatus) -> some View {
        switch status {
        case .finished:
            NoSpoilersStatusBadge(
                text: Strings.Sessions.finishedAgo(finishedAgo(since: effectiveEnd(of: session, nextSession: nextSession))),
                style: .finished
            )
        case .inProgress:
            NoSpoilersStatusBadge(textKey: NoSpoilersCore.Strings.Schedule.inProgress, style: .live)
        case .upcoming:
            NoSpoilersStatusBadge(text: countdown(to: session.startsAt), style: .upcoming)
        }
    }

    private func nextSessionStatus(for session: Session, in sessions: [Session]) -> String {
        let nextSession = nextChronologicalSession(after: session, in: sessions)
        switch SessionResolver.status(for: session, at: now, nextSession: nextSession, confirmedEndAt: store.confirmedEndDates[session.id]) {
        case .finished:
            return Strings.Sessions.sessionFinished(name: session.kind.displayName, ago: finishedAgo(since: effectiveEnd(of: session, nextSession: nextSession)))
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

    /// When a session is actually over — the confirmed end if we have one, otherwise the end of
    /// the grace window. Not `session.endsAt`, which is only the scheduled end and reads 90
    /// minutes early for a race.
    private func effectiveEnd(of session: Session, nextSession: Session?) -> Date {
        SessionResolver.effectiveEndDate(
            for: session,
            nextSession: nextSession,
            confirmedEndAt: store.confirmedEndDates[session.id]
        )
    }

    /// Tiers stop at minutes: this screen is glanced at, and a ticking seconds field would mean
    /// invalidating every page once a second. The macOS popover, which is open in front of you,
    /// deliberately goes finer.
    private func countdown(to date: Date) -> String {
        let remaining = DurationBreakdown(until: date, from: now)
        guard !remaining.isElapsed else { return Strings.Sessions.countdownNow }

        if remaining.days >= 1 { return Strings.Sessions.countdownDaysHours(remaining.days, remaining.hours) }
        if remaining.hours >= 1 { return Strings.Sessions.countdownHoursMinutes(remaining.hours, remaining.minutes) }
        return Strings.Sessions.countdownMinutes(remaining.minutes)
    }

    /// Hours here are `totalHours`, not hours-within-a-day: a session finished two days ago reads
    /// "48h", which is what this has always shown.
    private func finishedAgo(since date: Date) -> String {
        let elapsed = DurationBreakdown(since: date, to: now)
        if elapsed.totalHours >= 1 { return NoSpoilersCore.Strings.Schedule.durationHours(elapsed.totalHours) }
        return NoSpoilersCore.Strings.Schedule.durationMinutes(elapsed.minutes)
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
                // Reschedule: the interval this timer was built from may no longer be the right
                // one now that time has passed.
                setupRefreshTimer()
            }
    }

    private static let activeRefreshInterval: TimeInterval = 5 * 60
    private static let idleRefreshInterval: TimeInterval = 3600
    /// How far ahead of a session start the fast cadence kicks in.
    private static let imminentWindow: TimeInterval = 3600

    /// How long until the next refresh should happen.
    ///
    /// Five minutes while a session is live or about to start, hourly otherwise — but the idle
    /// case also wakes early enough to catch the moment the *next* session enters the imminent
    /// window. Returning a flat hour instead would mean a session starting 59 minutes after a
    /// check is not noticed until the following hourly tick, by which point it has already begun.
    private func refreshInterval() -> TimeInterval {
        var nextWake = Self.idleRefreshInterval

        for weekend in sortedWeekends {
            let sessions = weekend.allSessions
            for (i, session) in sessions.enumerated() {
                let next = i + 1 < sessions.count ? sessions[i + 1] : nil
                if SessionResolver.status(for: session, at: now, nextSession: next, confirmedEndAt: store.confirmedEndDates[session.id]) == .inProgress {
                    return Self.activeRefreshInterval
                }
                let untilStart = session.startsAt.timeIntervalSince(now)
                guard untilStart > 0 else { continue }
                if untilStart < Self.imminentWindow {
                    return Self.activeRefreshInterval
                }
                nextWake = min(nextWake, untilStart - Self.imminentWindow)
            }
        }
        // Never busy-loop, however close the boundary is.
        return max(60, nextWake)
    }

    private func initialWeekendIndex() -> Int {
        let weekends = sortedWeekends
        guard !weekends.isEmpty else { return 0 }

        // 1. Weekend with a current/in-progress session takes priority
        for (index, weekend) in weekends.enumerated() {
            let sessions = weekend.allSessions
            for (i, session) in sessions.enumerated() {
                let next = i + 1 < sessions.count ? sessions[i + 1] : nil
                if SessionResolver.status(for: session, at: now, nextSession: next, confirmedEndAt: store.confirmedEndDates[session.id]) == .inProgress {
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
