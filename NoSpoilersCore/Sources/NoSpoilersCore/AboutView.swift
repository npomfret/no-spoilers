import SwiftUI

/// Shared About / Acknowledgements screen used by both the macOS popover
/// and the iOS main view. Presented with a closure-based dismissal so the
/// host view owns the navigation model (macOS switches a screen enum; iOS
/// drives a sheet binding).
///
/// **This is the app's only menu**, so anything a platform needs a permanent
/// home for and does not want on the main screen goes in the `extra` slot —
/// iOS puts the widget instructions there. The slot is content the caller
/// builds, in the manner of `NoSpoilersCard` and `NoSpoilersDetailRow`, rather
/// than a platform flag read from inside: macOS has no Home Screen and the
/// steps would be wrong there, and the next thing to need this will not be
/// widget-shaped either.
public struct AboutView<Extra: View>: View {
    private let onDone: () -> Void
    private let extra: Extra

    public init(onDone: @escaping () -> Void, @ViewBuilder extra: () -> Extra) {
        self.onDone = onDone
        self.extra = extra()
    }

    /// Whether the caller actually put something in the slot.
    ///
    /// A section here is content plus the `Divider` under it, and the divider
    /// is ours rather than the caller's — every other section's is. An
    /// `EmptyView` draws nothing but a divider placed beside it still would,
    /// which is a stray line across the macOS popover.
    private var hasExtra: Bool { Extra.self != EmptyView.self }

    public var body: some View {
        VStack(spacing: 0) {
            // ── Header ──────────────────────────────────────────
            NoSpoilersScreenHeader(
                subtitle: Text(Strings.AppInfo.version(AppVersion.marketing, build: AppVersion.build))
            )

            Divider()

            // ── Platform section ──────────────────────────────
            // Above acknowledgements because it is the only thing here anyone
            // opens this screen to do; the credits below are reference.
            if hasExtra {
                extra
                Divider()
            }

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
                Divider().padding(.leading, Theme.Space.xxl)
                // The OFL asks for no in-app attribution — this row is here because
                // the other three are, and a bundled typeface is the same kind of
                // borrowed thing as a bundled flag set.
                acknowledgementRow(
                    title: Strings.About.typeface,
                    detail: "Chivo by Omnibus-Type",
                    url: URL(string: "https://github.com/Omnibus-Type/Chivo")!
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

extension AboutView where Extra == EmptyView {
    /// The plain screen, with nothing in the slot — macOS, and any caller that
    /// has nothing platform-specific to add.
    public init(onDone: @escaping () -> Void) {
        self.init(onDone: onDone, extra: { EmptyView() })
    }
}
