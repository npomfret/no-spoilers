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

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    public var body: some View {
        VStack(spacing: 0) {
            // ── Header ──────────────────────────────────────────
            VStack(spacing: 8) {
                Image("nospoilers-icon", bundle: .module)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                Text(Strings.AppInfo.name)
                    .font(.title3).fontWeight(.bold)
                Text("v\(version)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(BrandPalette.blush.opacity(0.5))

            Divider()

            // ── Acknowledgements ──────────────────────────────
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader(Strings.About.acknowledgements)

                acknowledgementRow(
                    title: Strings.About.scheduleData,
                    detail: "sportstimes/f1",
                    url: URL(string: "https://github.com/sportstimes/f1")!
                )
                Divider().padding(.leading, 16)
                acknowledgementRow(
                    title: Strings.About.sessionData,
                    detail: "OpenF1",
                    url: URL(string: "https://openf1.org")!
                )
                Divider().padding(.leading, 16)
                acknowledgementRow(
                    title: Strings.About.flagIcons,
                    detail: "flag-icons by Lipis",
                    url: URL(string: "https://github.com/lipis/flag-icons")!
                )
                Divider().padding(.leading, 16)
                acknowledgementRow(
                    title: Strings.About.branding,
                    detail: "Wikimedia Commons",
                    url: URL(string: "https://commons.wikimedia.org/wiki/File:Formula_One_logo.svg")!
                )
            }

            Divider()

            // ── Trademark disclaimer ──────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                sectionHeader(Strings.About.trademarks)
                Text(Strings.About.trademarkDisclaimer)
                    .font(.caption)
                    .foregroundStyle(BrandPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            Divider()

            // ── Footer ────────────────────────────────────────────
            HStack {
                Spacer()
                Button(Strings.About.done) { onDone() }
                    .keyboardShortcut(.defaultAction)
                #if os(macOS)
                    .controlSize(.small)
                #endif
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(NoSpoilersBackground())
    }

    private func sectionHeader(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .textCase(.uppercase)
            .font(.caption2).fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }

    private func acknowledgementRow(title: LocalizedStringKey, detail: String, url: URL) -> some View {
        HStack {
            Text(title).font(.body)
            Spacer()
            Link(destination: url) {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .underline()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }
}
