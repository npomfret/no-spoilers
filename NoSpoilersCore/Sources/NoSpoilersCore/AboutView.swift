import SwiftUI

/// Shared About / Acknowledgements screen used by both the macOS popover
/// and the iOS main view. Presented with a closure-based dismissal so the
/// host view owns the navigation model (macOS switches a screen enum; iOS
/// drives a sheet binding).
public struct AboutView: View {
    private let onDone: () -> Void

    public init(onDone: @escaping () -> Void) {
        self.onDone = onDone
    }

    public var body: some View {
        VStack(spacing: 0) {
            // ── Header ──────────────────────────────────────────
            NoSpoilersScreenHeader(
                subtitle: Text(Strings.AppInfo.version(AppVersion.marketing, build: AppVersion.build))
            )

            Divider()

            // ── Acknowledgements ──────────────────────────────
            VStack(alignment: .leading, spacing: 0) {
                NoSpoilersSectionLabel(Strings.About.acknowledgements)

                acknowledgementRow(
                    title: Strings.About.scheduleData,
                    detail: "sportstimes/f1",
                    url: URL(string: "https://github.com/sportstimes/f1")!
                )
                Divider().padding(.leading, Theme.Space.xxl)
                acknowledgementRow(
                    title: Strings.About.sessionData,
                    detail: "OpenF1",
                    url: URL(string: "https://openf1.org")!
                )
                Divider().padding(.leading, Theme.Space.xxl)
                acknowledgementRow(
                    title: Strings.About.flagIcons,
                    detail: "flag-icons by Lipis",
                    url: URL(string: "https://github.com/lipis/flag-icons")!
                )
            }

            Divider()

            // ── Trademark disclaimer ──────────────────────────
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                NoSpoilersSectionLabel(Strings.About.trademarks)
                Text(Strings.About.trademarkDisclaimer)
                    .font(.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Theme.Space.xxl)
                    .padding(.bottom, Theme.Space.xl)
            }

            Divider()

            // ── Footer ────────────────────────────────────────────
            HStack {
                Spacer()
                Button(Strings.Actions.done) { onDone() }
                    .keyboardShortcut(.defaultAction)
                #if os(macOS)
                    .controlSize(.small)
                #endif
            }
            .padding(.horizontal, Theme.Space.xxl)
            .padding(.vertical, Theme.Space.lg)
        }
        .background(NoSpoilersBackground())
        // NoSpoilersBackground is a hardcoded light gradient. Force the
        // subtree to resolve system text colours (`.primary`/`.secondary`/
        // `.tertiary`) via the light palette so contents stay readable
        // regardless of the host app's current colour scheme — important
        // when presented from the iOS sheet in a dark-mode device. Matches
        // the macOS popover-root behaviour in NoSpoilersMac/ContentView.
        .preferredColorScheme(.light)
    }


    private func acknowledgementRow(title: LocalizedStringKey, detail: String, url: URL) -> some View {
        NoSpoilersDetailRow(title) {
            Link(destination: url) {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .underline()
            }
        }
    }
}
