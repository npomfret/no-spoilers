import SwiftUI
import WidgetKit
import NoSpoilersCore

/// Whether this device has one of our widgets placed.
///
/// Three states, not a `Bool`, because `WidgetCenter` can fail to answer and *we do not know* is a
/// genuinely different thing from *there is no widget*. Collapsing them either shows a permanent,
/// undismissable nag to someone who already did the thing, or hides the guidance from the person
/// who needs it. Per the repo's fail-fast rule the unknown case is modelled rather than defaulted:
/// there is no `?? false` here.
enum WidgetInstallStatus {
    /// Not asked yet, or asked and not answered.
    case unknown
    case installed
    case notInstalled

    /// Asks WidgetKit what is currently on the user's screens.
    ///
    /// No entitlement and no permission prompt; this reports only our own widgets, and only their
    /// kind and family. Nothing about the user leaves the device.
    ///
    /// It does *not* report where a widget is. A widget in the Today View or on the Lock Screen
    /// counts as installed here, so the one user this card was written for — the one who lands in
    /// the Today View by mistake, which is what happened twice while taking the store screenshots —
    /// is the one it cannot detect. There is no API for placement, so the footer says it in words
    /// instead. Verified on the simulator: a widget-free device reports 0, a device with one on any
    /// screen reports 1.
    static func current() async -> WidgetInstallStatus {
        await withCheckedContinuation { continuation in
            WidgetCenter.shared.getCurrentConfigurations { result in
                switch result {
                // Both lines below are worth having because `.unknown` and `.installed` look
                // identical on screen — both show nothing — so without them there is no way to
                // tell a user who has the widget from a device where WidgetKit declined to answer.
                case .success(let widgets):
                    let placed = widgets.contains { $0.kind == NoSpoilersConfig.widgetKind }
                    AppLog.widget.notice("install check", ["configured": widgets.count,
                                                           "placed": placed])
                    continuation.resume(returning: placed ? .installed : .notInstalled)
                case .failure(let error):
                    // Not `.error`: WidgetCenter refusing to answer is a normal outcome here and
                    // resolves to `.unknown`, which deliberately shows nothing. See below.
                    AppLog.widget.notice("install check unavailable",
                                         ["error": LogValue.error(error)])
                    continuation.resume(returning: .unknown)
                }
            }
        }
    }

    /// Whether to show the guidance.
    ///
    /// Only for `.notInstalled`, so both `.unknown` cases stay quiet. That resolves the failure
    /// question deliberately, and in the direction the two errors are not symmetric: a user without
    /// the widget who misses this card still has a working app and will see it on the next launch
    /// that gets an answer, whereas a user who already added the widget cannot make a wrongly-shown
    /// card go away. Silence on unknown also covers the first moments after launch, before the
    /// query returns — otherwise the card would flash up and vanish for every existing user.
    var shouldPromptToInstall: Bool { self == .notInstalled }
}

/// Explains how to add the widget. Shown only while there isn't one.
///
/// There is deliberately no button that adds it. No public API places a widget — it is a user
/// gesture by design, and nothing in WidgetKit, `UIApplication`, or any URL scheme opens the widget
/// gallery. A button here would be a lie, so this instructs rather than acts.
struct WidgetInstallCard: View {
    var body: some View {
        NoSpoilersCard(canvas: .iosApp) {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                HStack(spacing: Theme.Space.lg) {
                    Image(systemName: Theme.Icon.widget)
                        .font(.title3)
                        .foregroundStyle(BrandPalette.signalRed)
                    Text(Strings.Widget.installTitle)
                        .font(.headline)
                        .foregroundStyle(Theme.Palette.textPrimary)
                }

                Text(Strings.Widget.installBody)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: Theme.Space.md) {
                    ForEach(Array(Strings.Widget.installSteps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: Theme.Space.lg) {
                            Text(String(index + 1))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                // A glyph diameter, not a gap — `Theme.Space` is
                                // the spacing rhythm and does not apply to it,
                                // same as the flag heights.
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(BrandPalette.signalRed))
                            Text(step)
                                .font(.subheadline)
                                .foregroundStyle(Theme.Palette.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Text(Strings.Widget.installFooter)
                    .font(.caption)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    WidgetInstallCard()
        .padding(16)
        .background(NoSpoilersBackground().ignoresSafeArea())
}
