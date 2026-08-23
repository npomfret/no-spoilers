import Combine
import SwiftUI
import NoSpoilersCore

struct ContentView: View {
    @EnvironmentObject private var store: ScheduleStore
    @EnvironmentObject private var alerts: SessionAlertScheduler
    @Environment(\.scenePhase) private var scenePhase
    @State private var now = Date()
    @State private var selectedWeekendIndex: Int = 0
    @State private var weekendsLoaded = false
    @State private var refreshTimer: AnyCancellable?
    @State private var showAbout = false
    @State private var showWidgetHelp = false
    @State private var showAlertSettings = false
    @State private var widgetInstall: WidgetInstallStatus = .unknown
    /// Whether the user has put the install prompt away. Local to the app, not
    /// the App Group: it is a preference of this screen and no extension has
    /// any business reading it. Keyed like the macOS menu-bar preferences.
    ///
    /// One-way on purpose. Nothing sets it back, because the only thing that
    /// could is another prompt, and a prompt that returns is the behaviour this
    /// replaced. The steps stay reachable from About.
    @AppStorage("widget.installPromptDismissed") private var installPromptDismissed = false

    var body: some View {
        VStack(spacing: 0) {
            // The app's chrome row: who you are looking at on the left, what you can do on the
            // right. The wordmark used to live inside the weekend's header card, which made the
            // app's own name a property of the weekend — redrawn on all 23 pages, and absent
            // entirely while the first schedule was still loading. It belongs above the pager.
            HStack(spacing: Theme.Space.xl) {
                NoSpoilersWordmark(size: .large)
                Spacer()
                // Swiping is otherwise the only way between 23 weekends, with page dots as the
                // only indication of where you are. If a swipe does not take — the thing this
                // screen was reported for — there is no other route back to the weekend that
                // matters. Only shown when you have actually navigated away from it.
                if let currentIndex = currentWeekendIndex, currentIndex != selectedWeekendIndex {
                    Button {
                        selectedWeekendIndex = currentIndex
                    } label: {
                        HStack(spacing: Theme.Space.xs) {
                            Image(systemName: Theme.Icon.currentWeekend)
                                .font(.caption2)
                            Text(Strings.Navigation.currentWeekend)
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Strings.Navigation.jumpToCurrentWeekend)
                }
                Button {
                    showAbout = true
                } label: {
                    Image(systemName: Theme.Icon.about)
                        .font(.title3)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(NoSpoilersCore.Strings.About.acknowledgements)
            }
            .padding(.horizontal, Theme.Space.xxl)
            .padding(.top, Theme.Space.md)
            .padding(.bottom, Theme.Space.xs)

            if store.isRefreshing && !weekendsLoaded {
                ScrollView {
                    skeletonView.padding(Theme.Space.xxl)
                }
                .refreshable { await refresh() }
            } else if sortedWeekends.isEmpty {
                ScrollView {
                    unavailableView.padding(Theme.Space.xxl)
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
                            weekendView(sortedWeekends[index]).padding(Theme.Space.xxl)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            }
        }
        .background(backgroundGradient)
        .sheet(isPresented: $showAbout) {
            AboutView(onDone: { showAbout = false }) {
                VStack(alignment: .leading, spacing: 0) {
                    widgetHelpSection
                    alertSettingsSection
                }
            }
            // Attached inside the About sheet rather than beside it: this is the
            // presenter, and a second `.sheet` on the root would have to wait for
            // About to close before it could open.
            .sheet(isPresented: $showWidgetHelp) {
                WidgetInstallSheet(onDone: { showWidgetHelp = false })
            }
            .sheet(isPresented: $showAlertSettings) {
                SessionAlertsView(onDone: { showAlertSettings = false })
            }
        }
        .onAppear {
            homeSelectionIfNeeded()
            setupRefreshTimer()
        }
        .task { await refresh() }
        .task { widgetInstall = await WidgetInstallStatus.current() }
        // Rescheduled from whatever the store holds now, and again whenever it changes. The
        // schedule arriving is what the pending alerts are made of, and on a cold launch it
        // arrives after this view does.
        .task { await alerts.reschedule(weekends: store.weekends, confirmedEndDates: store.confirmedEndDates) }
        .onChange(of: store.weekends) { _, weekends in
            Task { await alerts.reschedule(weekends: weekends, confirmedEndDates: store.confirmedEndDates) }
        }
        // The grant arrives while this view is on screen, underneath the About sheet the prompt
        // was asked from. Dismissing a sheet is not a scene change, so without this the answer
        // costs nothing until the app is next backgrounded and reopened: permission granted,
        // switches on, and not one alert pending.
        .onChange(of: alerts.authorization) { _, _ in
            Task { await alerts.reschedule(weekends: store.weekends, confirmedEndDates: store.confirmedEndDates) }
        }
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
            // Same reason the install check is re-asked here: the most likely thing to have
            // happened while we were backgrounded is the user changing their mind in Settings,
            // and a safe-to-watch alert placed on a grace-window estimate is corrected by the
            // confirmed end time arriving in the meantime.
            Task { await alerts.reschedule(weekends: store.weekends, confirmedEndDates: store.confirmedEndDates) }
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
                Theme.Palette.surfaceFinished
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

        return VStack(spacing: Theme.Space.xxl) {
            // First, because a user without the widget has not finished setting the app up and
            // that is the most useful thing on the screen for them. It scrolls away like any other
            // card, and it is gone for good the moment they act — or the moment they say no.
            if widgetInstall.shouldPromptToInstall && !installPromptDismissed {
                WidgetInstallCard(onDismiss: { installPromptDismissed = true })
            }
            headerCard(weekend: weekend, sessions: sessions, nextSession: nextSession)
            sessionCard(sessions: sessions)
            if nextSession != nil, let nextWeekend {
                nextWeekendCard(nextWeekend)
            }
        }
    }

    /// The widget's permanent home, handed to `AboutView`'s slot.
    ///
    /// A row that opens the steps rather than the steps themselves: About is a
    /// fixed-height sheet with three sections already in it, and inlining a
    /// numbered list would push the Done button off an iPhone SE.
    private var widgetHelpSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            NoSpoilersSectionLabel(Strings.Widget.aboutSectionLabel)
            Button {
                showWidgetHelp = true
            } label: {
                NoSpoilersDetailRow(Strings.Widget.aboutRowTitle) {
                    Image(systemName: Theme.Icon.disclosure)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    /// The alert preferences, in the same slot as the widget instructions.
    private var alertSettingsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            NoSpoilersSectionLabel(NoSpoilersCore.Strings.Alerts.sectionLabel)
            Button {
                showAlertSettings = true
            } label: {
                NoSpoilersDetailRow(NoSpoilersCore.Strings.Alerts.rowTitle) {
                    Image(systemName: Theme.Icon.disclosure)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func headerCard(weekend: RaceWeekend, sessions: [Session], nextSession: Session?) -> some View {
        let statusLine = nextSession.map { nextSessionStatus(for: $0, in: sessions) } ?? Strings.Sessions.weekendCompleteStatus()
        let isFinished = nextSession == nil

        return NoSpoilersCard(canvas: .iosApp) {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                // Centred rather than pushed to one edge: the wordmark that used to balance it
                // on the left is now in the chrome row, and the weekend's name below is centred.
                FlagImage(countryCode: weekend.countryCode, height: Theme.Header.flagHeight(.iosApp))
                    .frame(maxWidth: .infinity)

                Text(weekend.grandPrixName)
                    .font(Theme.Typography.weekendTitle(.iosApp))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                NoSpoilersWeekendMeta(
                    canvas: .iosApp,
                    round: weekend.round,
                    isFinished: isFinished,
                    location: weekend.location,
                    dateRange: weekendDateRange(of: sessions)
                )

                Text(statusLine)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
    }

    /// The span a weekend covers, or nil when it has no sessions to span.
    private func weekendDateRange(of sessions: [Session]) -> String? {
        guard let first = sessions.first, let last = sessions.last else { return nil }
        return NoSpoilersCore.Strings.Schedule.dateRange(from: first.startsAt, to: last.startsAt)
    }

    private func sessionCard(sessions: [Session]) -> some View {
        NoSpoilersCard(canvas: .iosApp) {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                Text(Strings.Sessions.header)
                    .font(.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)

                ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                    let nextSession = index + 1 < sessions.count ? sessions[index + 1] : nil
                    let status = SessionResolver.status(
                        for: session,
                        at: now,
                        nextSession: nextSession,
                        confirmedEndAt: store.confirmedEndDates[session.id]
                    )

                    NoSpoilersSessionRow(
                        canvas: .iosApp,
                        status: status,
                        name: Text(session.kind.displayName),
                        detail: Text(NoSpoilersCore.Strings.Schedule.sessionDateTime(session.startsAt))
                    ) {
                        statusBadge(for: session, nextSession: nextSession, status: status)
                    }
                }
            }
        }
    }

    private func nextWeekendCard(_ weekend: RaceWeekend) -> some View {
        // **The countdown used to fall back to the location** when a weekend had
        // no sessions to count down to, putting a place name where a time
        // belongs. The footer takes the absence directly and draws no second
        // line at all.
        let countdownText = weekend.allSessions.first.map { Text(countdown(to: $0.startsAt)) }

        return NoSpoilersCard(canvas: .iosApp) {
            NoSpoilersNextUpFooter(
                canvas: .iosApp,
                countryCode: weekend.countryCode,
                name: Text(weekend.grandPrixName),
                detail: countdownText
            ) {
                NoSpoilersRoundPill(NoSpoilersCore.Strings.Schedule.roundLabel(weekend.round))
            }
        }
    }

    /// What the screen looks like before the first schedule arrives.
    ///
    /// **It draws the real components, not lookalikes of them.** This used to
    /// hand-build a session row — its own 3pt accent rule, its own label stack,
    /// its own 10pt-radius white-65% panel — which made it the *fifth*
    /// implementation of the row `NoSpoilersSessionRow` replaced, and the last
    /// one still carrying the 10pt corner that convergence retired. A skeleton
    /// that drifts from the thing it stands in for is a skeleton of a screen
    /// this app no longer has.
    ///
    /// **The strings are `verbatim` on purpose.** They are shapes rather than
    /// copy — `.redacted(.placeholder)` paints every one of them as a grey bar,
    /// and none is ever read. Putting them through `Strings.swift` would hand a
    /// translator "Sat 00:00" to localise.
    private var skeletonView: some View {
        VStack(spacing: Theme.Space.xxl) {
            NoSpoilersCard(canvas: .iosApp) {
                VStack(alignment: .leading, spacing: Theme.Space.xl) {
                    HStack {
                        Spacer(minLength: 0)
                        Text(verbatim: "Loading Grand Prix")
                            .font(Theme.Typography.weekendTitle(.iosApp))
                        Spacer(minLength: 0)
                    }
                    NoSpoilersWeekendMeta(
                        canvas: .iosApp,
                        round: 0,
                        location: "Location",
                        dateRange: "1 Jan – 3 Jan"
                    )
                    Text(verbatim: "Next session in —")
                        .font(.subheadline)
                }
            }
            NoSpoilersCard(canvas: .iosApp) {
                VStack(alignment: .leading, spacing: Theme.Space.xl) {
                    Text(verbatim: "Sessions")
                        .font(.headline)
                    ForEach(0..<5, id: \.self) { _ in
                        NoSpoilersSessionRow(
                            canvas: .iosApp,
                            status: .upcoming,
                            name: Text(verbatim: "Free Practice 1"),
                            detail: Text(verbatim: "Sat 00:00")
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
            canvas: .iosApp
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
                style: .finished,
                canvas: .iosApp
            )
        case .inProgress:
            NoSpoilersStatusBadge(
                textKey: NoSpoilersCore.Strings.Schedule.inProgress,
                style: .live,
                canvas: .iosApp
            )
        case .upcoming:
            NoSpoilersStatusBadge(
                text: countdown(to: session.startsAt),
                style: .upcoming,
                canvas: .iosApp
            )
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
    /// deliberately goes finer — same formatter, different numbers.
    private static let countdownUnits = CountdownFormatter(units: 2, floor: .minutes)

    private func countdown(to date: Date) -> String {
        let remaining = DurationBreakdown(until: date, from: now)
        guard !remaining.isElapsed else { return Strings.Sessions.countdownNow }
        return Strings.Sessions.countdownIn(Self.countdownUnits.string(for: remaining))
    }

    /// Hours here are `totalHours`, not hours-within-a-day: a session finished two days ago reads
    /// "48h", which is what this has always shown.
    private func finishedAgo(since date: Date) -> String {
        let elapsed = DurationBreakdown(since: date, to: now)
        if elapsed.totalHours >= 1 { return NoSpoilersCore.Strings.Schedule.durationHours(elapsed.totalHours) }
        return NoSpoilersCore.Strings.Schedule.durationMinutes(elapsed.minutes)
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
