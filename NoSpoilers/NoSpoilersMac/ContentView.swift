import SwiftUI
import Combine
import ServiceManagement
import NoSpoilersCore

private let f1Red = BrandPalette.signalRed

// MARK: - MenuRowButtonStyle

private struct MenuRowButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered
                          ? Color.secondary.opacity(0.10)
                          : Color.clear)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: isHovered)
            .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

struct WeekendPopoverView: View {
    @ObservedObject var store: ScheduleStore
    @ObservedObject var updateChecker: UpdateChecker
    @State private var now: Date = Date()
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let now = self.now
        let current = RaceWeekendResolver.currentWeekend(in: store.weekends, at: now, confirmedEndDates: store.confirmedEndDates)

        VStack(spacing: 0) {
            Group {
                if let weekend = current {
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
                Button { openWindow(id: "settings") } label: {
                    Label(Strings.Popover.settings, systemImage: "gear")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(MenuRowButtonStyle())
                Button { NSApplication.shared.terminate(nil) } label: {
                    Label(Strings.Popover.quit, systemImage: "power")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(MenuRowButtonStyle())
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .background(
            LinearGradient(
                colors: [BrandPalette.ivory, BrandPalette.blush.opacity(0.45), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { tick in
            self.now = tick
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
            // Row 2: round pill · location · date range
            HStack(alignment: .center, spacing: 6) {
                Text("R\(weekend.round)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(f1Red)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(BrandPalette.blush.opacity(0.7))
                    .clipShape(Capsule())
                Text(weekend.location)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let first = weekend.allSessions.first, let last = weekend.allSessions.last {
                    let fmt = Date.FormatStyle().day().month(.abbreviated)
                    let start = first.startsAt.formatted(fmt)
                    let end   = last.startsAt.formatted(fmt)
                    Text(start == end ? start : "\(start) → \(end)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(BrandPalette.blush.opacity(0.3))
    }

    private func sessionList(_ weekend: RaceWeekend, now: Date) -> some View {
        let sessions = weekend.allSessions
        return VStack(spacing: 4) {
            ForEach(sessions.indices, id: \.self) { i in
                let next = i + 1 < sessions.count ? sessions[i + 1] : nil
                sessionRow(sessions[i], nextSession: next, at: now)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }

    private func sessionRow(_ session: Session, nextSession: Session?, at now: Date) -> some View {
        let status = SessionResolver.status(for: session, at: now, nextSession: nextSession, confirmedEndAt: store.confirmedEndDates[session.id])
        return HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(status == .finished ? BrandPalette.successGreen.opacity(0.6) : status == .inProgress ? f1Red : BrandPalette.mistGrey)
                .frame(width: 3, height: 28)
            Text(session.kind.displayName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(status == .finished ? BrandPalette.successGreen : .primary)
                .frame(minWidth: 100, alignment: .leading)
            Spacer()
            statusBadge(status: status, session: session, at: now)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.65))
        )
    }

    @ViewBuilder
    private func statusBadge(status: SessionStatus, session: Session, at now: Date) -> some View {
        switch status {
        case .finished:
            let secs = Int(now.timeIntervalSince(session.endsAt))
            let h = secs / 3600
            let m = (secs % 3600) / 60
            Text("Finished \(h > 0 ? "\(h)h" : "\(m)m") ago")
                .font(.caption)
                .foregroundStyle(BrandPalette.successGreen)
        case .inProgress:
            Text(Strings.Popover.inProgress)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(f1Red)
                .clipShape(Capsule())
        case .upcoming:
            Text(countdown(to: session.startsAt, from: now))
                .font(.caption)
                .foregroundStyle(BrandPalette.secondaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(BrandPalette.blush.opacity(0.55))
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
                .background(BrandPalette.blush.opacity(0.7))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var updateBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.up.circle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 12))
            Text(Strings.Popover.updateAvailable)
                .font(.caption)
                .foregroundStyle(.primary)
            Spacer()
            Text(Strings.Popover.brewUpgrade)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.08))
    }

    private var noDataView: some View {
        VStack(spacing: 10) {
            Text("🏁")
                .font(.system(size: 36))
            Text(Strings.Popover.offSeason)
                .font(.headline)
            Text(Strings.Popover.noSessions)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}

struct SettingsView: View {
    @AppStorage("menuBar.showFlag")      private var showFlag:      Bool = true
    @AppStorage("menuBar.showSession")   private var showSession:   Bool = true
    @AppStorage("menuBar.showCountdown") private var showCountdown: Bool = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──────────────────────────────────────────
            VStack(spacing: 8) {
                Image("nospoilers-icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                Text(Strings.Settings.appName)
                    .font(.title3).fontWeight(.bold)
                Text(Strings.Settings.tagline)
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(BrandPalette.blush.opacity(0.5))

            Divider()

            // ── Rows ─────────────────────────────────────────────
            settingRow(Strings.Settings.launchAtLogin) {
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
            sectionLabel(Strings.Settings.menuBar)
            settingRow(Strings.Settings.showFlag)      { Toggle("", isOn: $showFlag)      .labelsHidden().toggleStyle(.switch).controlSize(.small) }
            settingRow(Strings.Settings.showSession)   { Toggle("", isOn: $showSession)   .labelsHidden().toggleStyle(.switch).controlSize(.small) }
            settingRow(Strings.Settings.showCountdown) { Toggle("", isOn: $showCountdown) .labelsHidden().toggleStyle(.switch).controlSize(.small) }

            Divider()

            // ── Footer ────────────────────────────────────────────
            HStack {
                Spacer()
                Button(Strings.Settings.done) { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 280)
    }

    private func settingRow<C: View>(_ label: LocalizedStringKey, @ViewBuilder control: () -> C) -> some View {
        HStack {
            Text(label).font(.body)
            Spacer()
            control()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }

    private func sectionLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .textCase(.uppercase)
            .font(.caption2).fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 2)
    }
}
