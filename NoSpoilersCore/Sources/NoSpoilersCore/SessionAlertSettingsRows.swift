import SwiftUI

/// The alert preference rows, and the one moment this app asks for permission.
///
/// Shared because the *asking* is the part that must not be written twice. The iOS screen and the
/// macOS settings pane look nothing alike — a sheet with a header and a Done button against a row
/// in a popover — but the rule about when to spend the one-shot prompt is the same rule, and it
/// took three defects to get right the first time. A second copy would have started from whichever
/// of those was easiest to see.
///
/// Each platform owns its own frame and its own way to reach system settings, and passes the
/// latter in. That is the same shape `MenuBarPopoverRootView` uses for `dismissPopover`.
public struct SessionAlertSettingsRows: View {
    @AppStorage(SessionAlertDefaults.remindBeforeStartKey)
    private var remindBeforeStart = SessionAlertDefaults.remindBeforeStart

    @AppStorage(SessionAlertDefaults.startLeadMinutesKey)
    private var startLeadMinutes = SessionAlertDefaults.startLeadMinutes

    @AppStorage(SessionAlertDefaults.announceSafeToWatchKey)
    private var announceSafeToWatch = SessionAlertDefaults.announceSafeToWatch

    @AppStorage(SessionAlertDefaults.groupsKey)
    private var groupsRaw = SessionAlertDefaults.encode(SessionAlertDefaults.groups)

    @ObservedObject private var scheduler: SessionAlertScheduler
    private let onOpenSystemSettings: () -> Void

    public init(scheduler: SessionAlertScheduler, onOpenSystemSettings: @escaping () -> Void) {
        self.scheduler = scheduler
        self.onOpenSystemSettings = onOpenSystemSettings
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if scheduler.authorization == .denied {
                deniedNotice
            }

            NoSpoilersDetailRow(Strings.Alerts.remindBeforeStart) {
                switchToggle(isOn: $remindBeforeStart)
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
                switchToggle(isOn: $announceSafeToWatch)
            }

            NoSpoilersSectionLabel(Strings.Alerts.whichSessions)
            ForEach(SessionAlertGroup.allCases, id: \.self) { group in
                NoSpoilersDetailRow(group.displayName) {
                    switchToggle(isOn: binding(for: group))
                }
                // What the row covers, under the row. Two of the three are not guessable — the
                // Sprint is under Races and Sprint Qualifying is under Qualifying — and a switch
                // whose scope you have to infer is one people turn off to find out.
                Text(group.summary)
                    .font(.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.horizontal, Theme.Space.xxl)
                    .padding(.bottom, Theme.Space.sm)
            }
        }
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
    /// The prompt is one-shot for the life of the install, so it is spent at the point someone has
    /// found this screen, read what the alerts say, and left one switched on — not on launch,
    /// before anyone knows what the app is for, which is the reliable way to lose the permission
    /// permanently.
    ///
    /// **`.onChange` alone was not enough, and that was a silent hole.** Both alerts ship on, so
    /// `wantsAnything` is already true when this first draws and never changes — the prompt was
    /// therefore never shown to anybody who left the defaults alone, which is everybody.
    /// Authorization stayed `.notDetermined` for the life of the install, every reschedule logged
    /// `not scheduling`, and the screen looked completely correct while doing it. Found on
    /// 2026-08-22 by `scripts/alerts_check.py`, which is the only reason it was found at all.
    private func askIfWanted() async {
        guard wantsAnything, scheduler.authorization == .notDetermined else { return }
        await scheduler.requestAuthorization()
    }

    /// Whether any alert is switched on at all.
    private var wantsAnything: Bool { remindBeforeStart || announceSafeToWatch }

    /// The system has been told no, and the app cannot reopen that prompt — only settings can.
    private var deniedNotice: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text(Strings.Alerts.deniedTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(Strings.Alerts.deniedBody)
                .font(.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(Strings.Alerts.openSettings, action: onOpenSystemSettings)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, Theme.Space.xxl)
        .padding(.top, Theme.Space.xl)
    }

    private func binding(for group: SessionAlertGroup) -> Binding<Bool> {
        Binding(
            get: { SessionAlertDefaults.decode(groupsRaw).contains(group) },
            set: { isOn in
                var next = SessionAlertDefaults.decode(groupsRaw)
                if isOn { next.insert(group) } else { next.remove(group) }
                groupsRaw = SessionAlertDefaults.encode(next)
            }
        )
    }

    /// The macOS settings pane sizes its switches down; iOS leaves them alone. Applied here rather
    /// than by the caller so that adding a row cannot get it wrong on one platform.
    @ViewBuilder
    private func switchToggle(isOn: Binding<Bool>) -> some View {
        #if os(macOS)
        Toggle("", isOn: isOn).labelsHidden().toggleStyle(.switch).controlSize(.small)
        #else
        Toggle("", isOn: isOn).labelsHidden()
        #endif
    }
}
