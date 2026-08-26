import SwiftUI
import Combine
import ServiceManagement
import NoSpoilersCore

// MARK: - MenuRowButtonStyle

private struct MenuRowButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, Theme.Space.xl)
            .padding(.vertical, Theme.Space.sm)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                    .fill(isHovered
                          ? Theme.Palette.hoverFill
                          : Color.clear)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(Theme.Motion.hover, value: isHovered)
            .animation(Theme.Motion.press, value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

struct WeekendPopoverView: View {
    @ObservedObject var store: ScheduleStore
    @ObservedObject var updateChecker: UpdateChecker
    let openSettings: () -> Void
    let openAbout: () -> Void
    @State private var now: Date = Date()
    @State private var brewCopied = false

    var body: some View {
        let now = self.now
        let displayWeekend: RaceWeekend? = {
            if let previous = recentlyFinishedWeekend(at: now),
               now.timeIntervalSince(RaceWeekendResolver.effectiveEndDate(of: previous, confirmedEndDates: store.confirmedEndDates)) < 24 * 3600 {
                return previous
            }
            return RaceWeekendResolver.firstActiveWeekend(in: store.weekends, at: now, confirmedEndDates: store.confirmedEndDates)
        }()

        VStack(spacing: 0) {
            Group {
                if let weekend = displayWeekend {
                    weekendView(weekend, now: now)
                } else {
                    noDataView
                }
            }
            if updateChecker.isUpdateAvailable {
                Divider()
                updateBanner
            }
            Divider()
            VStack(spacing: 0) {
                Button { NSWorkspace.shared.open(URL(string: "https://npomfret.github.io/no-spoilers/")!) } label: {
                    Label(Strings.Popover.website, systemImage: Theme.Icon.website)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(MenuRowButtonStyle())
                Button { openAbout() } label: {
                    Label(Strings.Popover.about, systemImage: Theme.Icon.about)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(MenuRowButtonStyle())
                Button { openSettings() } label: {
                    Label(Strings.Popover.settings, systemImage: Theme.Icon.settings)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(MenuRowButtonStyle())
                Button { NSApplication.shared.terminate(nil) } label: {
                    Label(Strings.Popover.quit, systemImage: Theme.Icon.quit)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(MenuRowButtonStyle())
            }
            .padding(.horizontal, Theme.Space.xs)
            .padding(.vertical, Theme.Space.xs)
        }
        .background(NoSpoilersBackground())
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { tick in
            self.now = tick
        }
    }

    private func recentlyFinishedWeekend(at now: Date) -> RaceWeekend? {
        store.weekends
            .sorted { $0.round < $1.round }
            .last {
                !$0.allSessions.isEmpty &&
                RaceWeekendResolver.firstNonFinishedSession(in: $0, at: now, confirmedEndDates: store.confirmedEndDates) == nil
            }
    }

    private func weekendView(_ weekend: RaceWeekend, now: Date) -> some View {
        let nextWeekend = RaceWeekendResolver.nextWeekend(after: weekend, in: store.weekends)
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
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            // Row 1: logo · GP name (centered) · flag
            HStack(alignment: .center, spacing: Theme.Header.contentSpacing(.macPopover)) {
                NoSpoilersWordmark(size: .medium)
                Spacer()
                Text(weekend.grandPrixName)
                    .font(Theme.Typography.weekendTitle(.macPopover))
                    .multilineTextAlignment(.center)
                Spacer()
                FlagImage(countryCode: weekend.countryCode, height: Theme.Header.flagHeight(.macPopover))
            }
            // Row 2: round pill · location · date range
            NoSpoilersWeekendMeta(
                canvas: .macPopover,
                round: weekend.round,
                location: weekend.location,
                dateRange: weekendDateRange(of: weekend)
            )
        }
        .padding(.horizontal, Theme.Space.xxl)
        .padding(.vertical, Theme.Space.xl)
        .background(BrandPalette.blush.opacity(0.3))
    }

    /// The span a weekend covers, or nil when it has no sessions to span.
    private func weekendDateRange(of weekend: RaceWeekend) -> String? {
        guard let first = weekend.allSessions.first, let last = weekend.allSessions.last else {
            return nil
        }
        return NoSpoilersCore.Strings.Schedule.dateRange(from: first.startsAt, to: last.startsAt)
    }

    private func sessionList(_ weekend: RaceWeekend, now: Date) -> some View {
        let sessions = weekend.allSessions
        return VStack(spacing: Theme.Space.xs) {
            ForEach(sessions.indices, id: \.self) { i in
                let next = i + 1 < sessions.count ? sessions[i + 1] : nil
                sessionRow(sessions[i], nextSession: next, at: now)
            }
        }
        .padding(.horizontal, Theme.Space.lg)
        .padding(.vertical, Theme.Space.lg)
    }

    private func sessionRow(_ session: Session, nextSession: Session?, at now: Date) -> some View {
        let status = SessionResolver.status(for: session, at: now, nextSession: nextSession, confirmedEndAt: store.confirmedEndDates[session.id])
        return NoSpoilersSessionRow(
            canvas: .macPopover,
            status: status,
            name: Text(session.kind.displayName),
            detail: Text(NoSpoilersCore.Strings.Schedule.sessionDateTime(session.startsAt))
        ) {
            statusBadge(status: status, session: session, nextSession: nextSession, at: now)
        }
    }

    @ViewBuilder
    private func statusBadge(status: SessionStatus, session: Session, nextSession: Session?, at now: Date) -> some View {
        switch status {
        case .finished:
            // Measured from the effective end, not `session.endsAt`. The scheduled end is 90
            // minutes before a race is considered over, so this used to open at "finished 1h 40m
            // ago" the moment the session flipped.
            let endedAt = SessionResolver.effectiveEndDate(
                for: session,
                nextSession: nextSession,
                confirmedEndAt: store.confirmedEndDates[session.id]
            )
            NoSpoilersStatusBadge(
                text: Strings.Popover.finishedAgo(
                    Self.finishedUnits.string(for: DurationBreakdown(since: endedAt, to: now))
                ),
                style: .finished,
                canvas: .macPopover
            )
        case .inProgress:
            NoSpoilersStatusBadge(
                textKey: NoSpoilersCore.Strings.Schedule.inProgress,
                style: .live,
                canvas: .macPopover
            )
        case .upcoming:
            NoSpoilersStatusBadge(
                text: countdown(to: session.startsAt, from: now),
                style: .upcoming,
                canvas: .macPopover
            )
        }
    }

    /// Goes all the way down to seconds, unlike iOS. The popover is open in front of you while you
    /// read it, so a static minutes reading looks frozen. Shows no "in" prefix — the popover has
    /// the session name beside it doing that work.
    private static let countdownUnits = CountdownFormatter(units: 3, floor: .seconds)

    /// One unit, and minutes rather than the seconds `countdownUnits` uses: a finished badge is a
    /// fact that is not going to change, so ticking it is noise where ticking a countdown is not.
    ///
    /// **Shares iOS's fix and its reason.** This site had the same unbounded `totalHours` ladder
    /// written out a second time, so the popover counted a finished session upwards in hours with
    /// no days tier, forever. See the comment on `finishedUnits` in the iOS `ContentView`.
    private static let finishedUnits = CountdownFormatter(units: 1, floor: .minutes)

    private func countdown(to date: Date, from now: Date) -> String {
        let remaining = DurationBreakdown(until: date, from: now)
        guard !remaining.isElapsed else { return Strings.Popover.countdownZero }
        return Self.countdownUnits.string(for: remaining)
    }

    private func nextRoundFooter(_ weekend: RaceWeekend, now: Date) -> some View {
        NoSpoilersNextUpFooter(
            canvas: .macPopover,
            countryCode: weekend.countryCode,
            name: Text(weekend.grandPrixName),
            detail: nextRoundDetail(weekend, now: now)
        ) {
            NoSpoilersRoundPill(NoSpoilersCore.Strings.Schedule.roundLabel(weekend.round))
        }
        .padding(.horizontal, Theme.Space.xxl)
        .padding(.vertical, Theme.Space.md)
    }

    /// When the next weekend races and how long until it starts, or nil when the
    /// feed gave us neither.
    ///
    /// **These were two `Text`s in their own `HStack`** before the footer
    /// converged — same font, same colour, 4pt apart. One string with the
    /// bullet already in it renders the same line without a nested stack.
    private func nextRoundDetail(_ weekend: RaceWeekend, now: Date) -> Text? {
        let raceDate = weekend.sessions[.race] ?? weekend.sessions[.sprint]
        let parts = [
            raceDate.map { $0.formatted(.dateTime.day().month(.abbreviated)) },
            weekend.allSessions.first.map {
                Strings.Popover.countdownWithBullet(countdown(to: $0.startsAt, from: now))
            },
        ].compactMap(\.self)
        guard !parts.isEmpty else { return nil }
        return Text(parts.joined(separator: " "))
    }

    private var updateBanner: some View {
        HStack(spacing: Theme.Space.sm) {
            Image(systemName: Theme.Icon.updateAvailable)
                .foregroundStyle(Theme.Palette.attention)
                .font(.system(size: 12))
            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                Text(Strings.Popover.updateAvailable)
                    .font(.caption)
                    .foregroundStyle(Theme.Palette.textPrimary)
                if !updateChecker.latestVersion.isEmpty {
                    Text("v\(updateChecker.currentVersion) → v\(updateChecker.latestVersion)")
                        .font(.caption2)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
            Spacer()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(Strings.Popover.brewUpgradeCommand, forType: .string)
                brewCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + Theme.Motion.confirmationHold) { brewCopied = false }
            } label: {
                Text(brewCopied ? Strings.Popover.copied : Strings.Popover.copyCommand)
                    .font(.caption2)
                    .foregroundStyle(brewCopied ? Theme.Palette.confirmation : Theme.Palette.textTertiary)
                    .animation(Theme.Motion.confirm, value: brewCopied)
            }
            .buttonStyle(.plain)
            .help(Strings.Popover.brewUpgradeCommand)
        }
        .padding(.horizontal, Theme.Space.xxl)
        .padding(.vertical, Theme.Space.md)
        .background(Theme.Palette.attention.opacity(0.08))
    }

    private var noDataView: some View {
        NoSpoilersMessageCard(
            title: Text(Strings.Popover.offSeason),
            bodyText: Text(Strings.Popover.noSessions),
            canvas: .macPopover
        )
        .padding(Theme.Space.xxl)
    }
}

struct MenuBarPopoverRootView: View {
    private enum Screen {
        case weekend
        case settings
        case about
    }

    @ObservedObject var store: ScheduleStore
    @ObservedObject var updateChecker: UpdateChecker
    @ObservedObject var alerts: SessionAlertScheduler
    let dismissPopover: () -> Void
    @State private var screen: Screen = .weekend

    var body: some View {
        Group {
            switch screen {
            case .weekend:
                WeekendPopoverView(
                    store: store,
                    updateChecker: updateChecker,
                    openSettings: { screen = .settings },
                    openAbout: { screen = .about }
                )
            case .settings:
                SettingsView(alerts: alerts, onDone: dismissPopover)
            case .about:
                AboutView(onDone: { screen = .weekend })
            }
        }
        .frame(width: 300)
        // Popover uses a hardcoded light gradient brand aesthetic; force the
        // SwiftUI subtree to resolve `.primary`/`.secondary`/`.tertiary` via
        // the light colour palette so text stays readable regardless of the
        // user's system appearance. See Guideline 4 rejection, April 2026.
        .preferredColorScheme(.light)
    }
}

struct SettingsView: View {
    @AppStorage("menuBar.showFlag")      private var showFlag:      Bool = false
    @AppStorage("menuBar.showSession")   private var showSession:   Bool = false
    @AppStorage("menuBar.showCountdown") private var showCountdown: Bool = true
    @ObservedObject var alerts: SessionAlertScheduler
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──────────────────────────────────────────
            NoSpoilersScreenHeader(subtitle: Text(Strings.Settings.tagline))

            Divider()

            // ── Rows ─────────────────────────────────────────────
            NoSpoilersDetailRow(Strings.Settings.launchAtLogin) {
                Toggle("", isOn: Binding(
                    get: { SMAppService.mainApp.status == .enabled },
                    set: { on in
                        if on { try? SMAppService.mainApp.register() }
                        else  { try? SMAppService.mainApp.unregister() }
                    }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
            }
            NoSpoilersSectionLabel(Strings.Settings.menuBar)
            NoSpoilersDetailRow(Strings.Settings.showFlag)      { Toggle("", isOn: $showFlag)      .labelsHidden().toggleStyle(.switch).controlSize(.small) }
            NoSpoilersDetailRow(Strings.Settings.showSession)   { Toggle("", isOn: $showSession)   .labelsHidden().toggleStyle(.switch).controlSize(.small) }
            NoSpoilersDetailRow(Strings.Settings.showCountdown) { Toggle("", isOn: $showCountdown) .labelsHidden().toggleStyle(.switch).controlSize(.small) }

            // The same rows the iOS screen shows, from Core. Only the frame and the route to
            // system settings differ per platform; the rule about when to spend the one-shot
            // permission prompt is shared, because it is the part that took three defects to get
            // right and must not exist twice.
            NoSpoilersSectionLabel(NoSpoilersCore.Strings.Alerts.sectionLabel)
            SessionAlertSettingsRows(scheduler: alerts, onOpenSystemSettings: openNotificationSettings)

            Divider()

            // ── Footer ────────────────────────────────────────────
            HStack {
                Spacer()
                Button(NoSpoilersCore.Strings.Actions.done) { onDone() }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.small)
            }
            .padding(.horizontal, Theme.Space.xxl)
            .padding(.vertical, Theme.Space.lg)
        }
        .background(NoSpoilersBackground())
    }

    /// The Notifications pane, which is the only place a denied prompt can be undone.
    ///
    /// `x-apple.systempreferences:` with the extension identifier rather than the old
    /// `com.apple.preference.notifications`: the pane was rewritten in Ventura and this app
    /// requires macOS 14, so the modern identifier is the one that is always right here.
    private func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }
}
