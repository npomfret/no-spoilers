import SwiftUI
import NoSpoilersCore

/// The alert preferences, opened from the row in About.
///
/// Same surface as `AboutView` and `WidgetInstallSheet` — shared screen header, scrolling body,
/// Done footer — because it is presented the same way and from the same place.
///
/// **The rows themselves are `SessionAlertSettingsRows` in Core**, shared with the macOS settings
/// pane. What is left here is the frame this platform puts around them and the way this platform
/// reaches its notification settings. The prompt logic is deliberately not here: it is the part
/// that took three defects to get right, and it must not exist twice.
struct SessionAlertsView: View {
    @EnvironmentObject private var scheduler: SessionAlertScheduler
    /// Here because this is the screen about what the app puts in front of you without being
    /// opened, and a Lock Screen countdown is that. It is not in `SessionAlertSettingsRows`:
    /// those rows are shared with the Mac app, which has no ActivityKit and nothing to say here.
    @EnvironmentObject private var activities: SessionActivityController
    @Environment(\.openURL) private var openURL

    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            NoSpoilersScreenHeader(subtitle: Text(NoSpoilersCore.Strings.Alerts.screenSubtitle))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(NoSpoilersCore.Strings.Alerts.intro)
                        .font(.subheadline)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Theme.Space.xxl)
                        .padding(.top, Theme.Space.xl)

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
        // Matches AboutView: NoSpoilersBackground is a hardcoded light gradient, so the subtree
        // has to resolve system colours light or the text goes unreadable on a dark-mode device.
        .preferredColorScheme(.light)
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
    SessionAlertsView(onDone: {})
        .environmentObject(SessionAlertScheduler())
        .environmentObject(SessionActivityController())
}
