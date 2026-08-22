import SwiftUI
import UserNotifications
import NoSpoilersCore

/// The alert preferences, opened from the row in About.
///
/// Same surface as `AboutView` and `WidgetInstallSheet` — shared screen header, scrolling body,
/// Done footer — because it is presented the same way and from the same place. The rows are
/// `NoSpoilersDetailRow` with a control trailing, which is what the macOS settings screen already
/// is; this is that pattern on the other platform, not a second one.
struct SessionAlertsView: View {
    @AppStorage(SessionAlertDefaults.remindBeforeStartKey)
    private var remindBeforeStart = SessionAlertDefaults.remindBeforeStart

    @AppStorage(SessionAlertDefaults.startLeadMinutesKey)
    private var startLeadMinutes = SessionAlertDefaults.startLeadMinutes

    @AppStorage(SessionAlertDefaults.announceSafeToWatchKey)
    private var announceSafeToWatch = SessionAlertDefaults.announceSafeToWatch

    @AppStorage(SessionAlertDefaults.kindsKey)
    private var kindsRaw = SessionAlertDefaults.encode(SessionAlertDefaults.kinds)

    @EnvironmentObject private var scheduler: SessionAlertScheduler
    @Environment(\.openURL) private var openURL

    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            NoSpoilersScreenHeader(subtitle: Text(Strings.Alerts.screenSubtitle))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(Strings.Alerts.intro)
                        .font(.subheadline)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Theme.Space.xxl)
                        .padding(.top, Theme.Space.xl)

                    if scheduler.authorization == .denied {
                        deniedNotice
                    }

                    NoSpoilersDetailRow(Strings.Alerts.remindBeforeStart) {
                        Toggle("", isOn: $remindBeforeStart).labelsHidden()
                    }
                    if remindBeforeStart {
                        NoSpoilersDetailRow(Strings.Alerts.leadTime) {
                            Picker("", selection: $startLeadMinutes) {
                                ForEach(SessionAlertDefaults.leadChoices, id: \.self) { minutes in
                                    Text(Strings.Alerts.leadMinutes(minutes)).tag(minutes)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }
                    }
                    NoSpoilersDetailRow(Strings.Alerts.announceSafeToWatch) {
                        Toggle("", isOn: $announceSafeToWatch).labelsHidden()
                    }

                    NoSpoilersSectionLabel(Strings.Alerts.whichSessions)
                    ForEach(SessionKind.allCases, id: \.self) { kind in
                        NoSpoilersDetailRow(kind.displayName) {
                            Toggle("", isOn: binding(for: kind)).labelsHidden()
                        }
                    }
                }
                .padding(.bottom, Theme.Space.xl)
            }

            Divider()

            HStack {
                Spacer()
                Button(NoSpoilersCore.Strings.Actions.done) { onDone() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, Theme.Space.xxl)
            .padding(.vertical, Theme.Space.lg)
        }
        .background(NoSpoilersBackground())
        // Matches AboutView: NoSpoilersBackground is a hardcoded light gradient, so the subtree
        // has to resolve system colours light or the text goes unreadable on a dark-mode device.
        .preferredColorScheme(.light)
        .task {
            await scheduler.refreshAuthorization()
            await askIfWanted()
        }
        .onChange(of: wantsAnything) { _, _ in
            Task { await askIfWanted() }
        }
    }

    /// Asked from this screen and nowhere else, the first time it is opened with an alert on.
    ///
    /// The prompt is one-shot for the life of the install, so it is spent at the point someone
    /// has found this screen, read what the alerts say, and left one switched on — not on launch,
    /// before anyone knows what the app is for, which is the reliable way to lose the permission
    /// permanently.
    ///
    /// **`.onChange` alone was not enough, and that was a silent hole.** Both alerts ship on, so
    /// `wantsAnything` is already true when this screen first draws and never changes — the
    /// prompt was therefore never shown to anybody who left the defaults alone, which is
    /// everybody. Authorization stayed `.notDetermined` for the life of the install, every
    /// reschedule logged `not scheduling`, and the screen looked completely correct while doing
    /// it: two switches on, no warning, no alerts. Found on 2026-08-22 by
    /// `scripts/alerts_check.py`, which is the only reason it was found at all.
    private func askIfWanted() async {
        guard wantsAnything, scheduler.authorization == .notDetermined else { return }
        await scheduler.requestAuthorization()
    }

    /// Whether any alert is switched on at all.
    private var wantsAnything: Bool { remindBeforeStart || announceSafeToWatch }

    /// iOS has been told no, and the app cannot reopen that prompt — only Settings can.
    private var deniedNotice: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text(Strings.Alerts.deniedTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(Strings.Alerts.deniedBody)
                .font(.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(Strings.Alerts.openSettings) {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
            }
            .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, Theme.Space.xxl)
        .padding(.top, Theme.Space.xl)
    }

    private func binding(for kind: SessionKind) -> Binding<Bool> {
        Binding(
            get: { SessionAlertDefaults.decode(kindsRaw).contains(kind) },
            set: { isOn in
                var next = SessionAlertDefaults.decode(kindsRaw)
                if isOn { next.insert(kind) } else { next.remove(kind) }
                kindsRaw = SessionAlertDefaults.encode(next)
            }
        )
    }
}

#Preview {
    SessionAlertsView(onDone: {})
        .environmentObject(SessionAlertScheduler())
}
