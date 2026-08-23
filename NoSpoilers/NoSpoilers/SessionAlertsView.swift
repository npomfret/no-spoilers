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

                    SessionAlertSettingsRows(scheduler: scheduler, onOpenSystemSettings: {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(url)
                    })
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
}

#Preview {
    SessionAlertsView(onDone: {})
        .environmentObject(SessionAlertScheduler())
}
