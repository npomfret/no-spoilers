import SwiftUI
import NoSpoilersCore

/// A numbered list of gestures, with a reason above it and a warning below.
///
/// **Generalised out of `WidgetInstallSteps` rather than copied.** That view existed so the install
/// nudge and the About sheet could not drift apart on a three-step sequence; the moment a second
/// sequence needed the same treatment, the choice was one parameterised view or two hand-kept
/// copies of the numbering, the red circles and the spacing. This is the first.
///
/// `footer` is optional because not every sequence has a place people get it wrong, and an empty
/// `Text` would still take the spacing.
struct HelpSteps: View {
    /// Named `intro` and not `body`, which is SwiftUI's.
    let intro: LocalizedStringKey
    let steps: [LocalizedStringKey]
    var footer: LocalizedStringKey?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xl) {
            Text(intro)
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: Theme.Space.md) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: Theme.Space.lg) {
                        Text(String(index + 1))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            // A glyph diameter, not a gap — `Theme.Space` is the spacing rhythm
                            // and does not apply to it, same as the flag heights.
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(BrandPalette.signalRed))
                        Text(step)
                            .font(.subheadline)
                            .foregroundStyle(Theme.Palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// One capability: a glyph, a name, and whatever explaining it takes.
private struct HelpSection<Content: View>: View {
    let icon: String
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.lg) {
            HStack(spacing: Theme.Space.lg) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(BrandPalette.signalRed)
                    // Fixed so the titles line up whatever glyph each section uses; SF Symbols
                    // are not a uniform width and a ragged left edge reads as a mistake.
                    .frame(width: 28, alignment: .leading)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
            }
            content
        }
    }
}

/// Everything this app can do that is not the screen you are looking at.
///
/// **The app could do six things and explained one.** The Home Screen widget had a nudge on the
/// main screen *and* a permanent page in About; the Lock Screen widgets, the Live Activity, the
/// Siri action and the iPad size had nothing anywhere. Each of those is undiscoverable by
/// construction — an accessory widget is added through Lock Screen customisation, an activity
/// appears only when a session is close, and a spoken phrase has to be guessed — so a feature
/// nobody is told about is a feature nobody has.
///
/// **This replaces `WidgetInstallSheet` rather than sitting beside it.** Two sheets reachable from
/// About, one of them a subset of the other, is the drift the widget steps were extracted to avoid
/// in the first place. The install nudge on the main screen stays: it is a prompt about a specific
/// missing thing, not a menu.
///
/// Same frame as `AboutView` and `SessionAlertsView` — shared screen header, scrolling body, Done
/// footer — because it is presented the same way and from the same place.
struct HelpSheet: View {
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            NoSpoilersScreenHeader(subtitle: Text(Strings.Help.screenSubtitle))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.xxl) {
                    Text(Strings.Help.intro)
                        .font(.subheadline)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HelpSection(icon: Theme.Icon.widget, title: Strings.Help.homeScreenTitle) {
                        // The same three steps the nudge shows, from the same strings. This is why
                        // `WidgetInstallSteps` exists.
                        WidgetInstallSteps()
                    }

                    HelpSection(icon: Theme.Icon.lockScreen, title: Strings.Help.lockScreenTitle) {
                        HelpSteps(
                            intro: Strings.Help.lockScreenBody,
                            steps: Strings.Help.lockScreenSteps,
                            footer: Strings.Help.lockScreenFooter
                        )
                    }

                    HelpSection(icon: Theme.Icon.sessionCountdown, title: Strings.Help.countdownTitle) {
                        paragraph(Strings.Help.countdownBody)
                    }

                    HelpSection(icon: Theme.Icon.alerts, title: Strings.Help.alertsTitle) {
                        paragraph(Strings.Help.alertsBody)
                    }

                    HelpSection(icon: Theme.Icon.siri, title: Strings.Help.siriTitle) {
                        VStack(alignment: .leading, spacing: Theme.Space.md) {
                            // The phrase, set apart, because it is the one thing on this screen a
                            // reader has to reproduce exactly rather than understand.
                            Text(Strings.Help.siriPhrase)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.Palette.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            paragraph(Strings.Help.siriBody)
                        }
                    }

                    HelpSection(icon: Theme.Icon.widget, title: Strings.Help.iPadTitle) {
                        paragraph(Strings.Help.iPadBody)
                    }
                }
                .padding(Theme.Space.xxl)
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

    private func paragraph(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Theme.Palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    HelpSheet(onDone: {})
}
