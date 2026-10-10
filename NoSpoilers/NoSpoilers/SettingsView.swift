import SwiftUI
import NoSpoilersCore

/// The app's settings, opened from the gear in the chrome row.
///
/// **Was `SessionAlertsView`, reached only from a row inside About, until 2026-10-10.** Settings
/// hidden under an info button is settings nobody finds; the macOS popover already had Settings
/// as its own screen beside About, and this is the iOS side of the same split.
///
/// Same surface as `AboutView` and `HelpSheet` — shared screen header, scrolling body, Done
/// footer — because it is presented the same way.
///
/// **The alert rows themselves are `SessionAlertSettingsRows` in Core**, shared with the macOS
/// settings pane. What is left here is the frame this platform puts around them and the way this
/// platform reaches its notification settings. The prompt logic is deliberately not here: it is
/// the part that took three defects to get right, and it must not exist twice.
struct SettingsView: View {
    @EnvironmentObject private var scheduler: SessionAlertScheduler
    /// Here because this is the screen about what the app puts in front of you without being
    /// opened, and a Lock Screen countdown is that. It is not in `SessionAlertSettingsRows`:
    /// those rows are shared with the Mac app, which has no ActivityKit and nothing to say here.
    @EnvironmentObject private var activities: SessionActivityController
    @Environment(\.openURL) private var openURL

    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            NoSpoilersScreenHeader(subtitle: Text(Strings.Settings.screenSubtitle))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Labelled as the macOS settings pane labels it, now that alerts are one
                    // section of a settings screen rather than the whole of a screen of their own.
                    NoSpoilersSectionLabel(NoSpoilersCore.Strings.Alerts.sectionLabel)
                    Text(NoSpoilersCore.Strings.Alerts.intro)
                        .font(.subheadline)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Theme.Space.xxl)

                    SessionAlertSettingsRows(scheduler: scheduler, onOpenSystemSettings: openSettings)

                    NoSpoilersSectionLabel(Strings.Activity.sectionLabel)
                    if activities.activitiesEnabled {
                        Text(Strings.Activity.intro)
                            .font(.caption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, Theme.Space.xxl)
                    } else {
                        activitiesOffNotice
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
    }

    /// Says so when iOS is holding the countdown back.
    ///
    /// Same shape as `SessionAlertSettingsRows.deniedNotice` — title, reason, a way to Settings —
    /// because it is the same situation and a second idiom for it would be one to keep in step.
    /// **The refusal it reports is the one nobody knew existed**: iOS asks
    /// "Allow Live Activities from No Spoilers?" on the first activity, and until 2026-08-25 a
    /// Don't Allow made the feature vanish with nothing anywhere admitting why.
    private var activitiesOffNotice: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text(Strings.Activity.deniedTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(Strings.Activity.deniedBody)
                .font(.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(NoSpoilersCore.Strings.Alerts.openSettings, action: openSettings)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, Theme.Space.xxl)
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

#Preview {
    SettingsView(onDone: {})
        .environmentObject(SessionAlertScheduler())
        .environmentObject(SessionActivityController())
}
