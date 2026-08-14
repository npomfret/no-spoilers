import SwiftUI
import WidgetKit
import OSLog
import NoSpoilersCore

/// Matches the widget target's logger shape (`NoSpoilersWidget.swift`), one category down.
///
/// Worth having because `.unknown` and `.installed` look identical on screen — both show nothing —
/// so without a line in the log there is no way to tell a user who has the widget from a device
/// where WidgetKit declined to answer.
private let log = Logger(subsystem: "pomocorp.NoSpoilers.NoSpoilersMac", category: "widget-install")

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
                case .success(let widgets):
                    let placed = widgets.contains { $0.kind == NoSpoilersConfig.widgetKind }
                    log.info("WidgetCenter reported \(widgets.count) widget(s); ours placed: \(placed)")
                    continuation.resume(returning: placed ? .installed : .notInstalled)
                case .failure(let error):
                    log.info("WidgetCenter could not say what is installed: \(error.localizedDescription)")
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
        NoSpoilersCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.title3)
                        .foregroundStyle(BrandPalette.signalRed)
                    Text(Strings.Widget.installTitle)
                        .font(.headline)
                        .foregroundStyle(BrandPalette.smoke)
                }

                Text(Strings.Widget.installBody)
                    .font(.subheadline)
                    .foregroundStyle(BrandPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(Strings.Widget.installSteps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 10) {
                            Text(String(index + 1))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(BrandPalette.signalRed))
                            Text(step)
                                .font(.subheadline)
                                .foregroundStyle(BrandPalette.smoke)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Text(Strings.Widget.installFooter)
                    .font(.caption)
                    .foregroundStyle(BrandPalette.tertiaryText)
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
