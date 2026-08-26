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

    /// Whether this state warrants the prompt. Not the whole condition — the
    /// screen also checks whether the user has already put it away.
    ///
    /// Only for `.notInstalled`, so both `.unknown` cases stay quiet. That resolves the failure
    /// question deliberately, and in the direction the two errors are not symmetric: a user without
    /// the widget who misses this card still has a working app and will see it on the next launch
    /// that gets an answer, whereas a user who already added the widget cannot make a wrongly-shown
    /// card go away. Silence on unknown also covers the first moments after launch, before the
    /// query returns — otherwise the card would flash up and vanish for every existing user.
    var shouldPromptToInstall: Bool { self == .notInstalled }
}

/// The instructions themselves: why, the three steps, and the one place people
/// get it wrong.
///
/// **Extracted so the prompt and the menu cannot drift.** `WidgetInstallCard`
/// below is a one-off nudge a user can put away for good; `HelpSheet` is where
/// the steps live permanently, for whoever dismissed the nudge or wants a
/// second widget later. Two copies of a three-step sequence is exactly the kind
/// of thing that gets edited once.
///
/// **The drawing moved to `HelpSteps` on 2026-08-26** when the Lock Screen
/// needed the same treatment. What is left here is the binding of these three
/// particular strings, which is the part that must not be written twice.
struct WidgetInstallSteps: View {
    var body: some View {
        HelpSteps(
            intro: Strings.Widget.installBody,
            steps: Strings.Widget.installSteps,
            footer: Strings.Widget.installFooter
        )
    }
}

/// The nudge on the main screen. Shown only while there isn't a widget **and**
/// the user has not put it away.
///
/// There is deliberately no button that adds it. No public API places a widget —
/// it is a user gesture by design, and nothing in WidgetKit, `UIApplication`, or
/// any URL scheme opens the widget gallery. A button here would be a lie, so
/// this instructs rather than acts.
///
/// **It used to have no way out.** `.notInstalled` is a durable state for anyone
/// who decides they do not want a widget, so the card sat on top of every one of
/// the twenty-three weekend pages, on every launch, for the rest of the season.
/// Dismissing does not hide the instructions, it moves them: `HelpSheet` is
/// reachable from About at any time.
struct WidgetInstallCard: View {
    let onDismiss: () -> Void

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

                WidgetInstallSteps()

                Button(action: onDismiss) {
                    Text(Strings.Widget.dismissPrompt)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    WidgetInstallCard(onDismiss: {})
        .padding(Theme.Space.xxl)
        .background(NoSpoilersBackground().ignoresSafeArea())
}
