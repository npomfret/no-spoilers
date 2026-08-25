import ActivityKit
import SwiftUI
import WidgetKit
import NoSpoilersCore

/// The Live Activity: the next session, on the Lock Screen and in the Dynamic Island.
///
/// **Hosted in the widget extension rather than a target of its own**, which is what ActivityKit
/// expects and what `NoSpoilersWidgetBundle` already exists to do. Nothing about the project layout
/// changes for this.
///
/// **No server and no push.** `Activity.request` is called from the foreground by
/// `SessionActivityController`; push-to-start needs APNs and would need a backend this product does
/// not have. The consequence is the shape of the feature: the countdown appears when the app is
/// opened, not by itself, and it is one activity for the *next* session rather than one for the
/// weekend — see `SessionActivityController.lookAhead`.
///
/// **The same three fields as every other family** — the Grand Prix, the session, a clock. This is
/// content on a locked screen the reader cannot decline to look at, so it is deliberately a
/// different arrangement of what is already audited rather than a new place to put something.
struct SessionActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionActivityAttributes.self) { context in
            SessionActivityLockScreenView(
                attributes: context.attributes,
                state: context.state
            )
            // A flat tint rather than `NoSpoilersBackground`: this is the one surface where the
            // system owns the container and takes a colour, not a view. Ivory is the same ground
            // the gradient starts from, so the activity reads as the app's without pretending to
            // be a card.
            .activityBackgroundTint(BrandPalette.ivory)
            .activitySystemActionForegroundColor(Theme.Palette.textPrimary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.sessionName)
                        .font(Theme.Typography.eyebrow)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    SessionActivityClock(state: context.state)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.grandPrixName)
                        .font(.headline)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(1)
                }
            } compactLeading: {
                SessionActivityGlyph(state: context.state)
            } compactTrailing: {
                // Nothing while the session is running. The compact slot is a few points wide and
                // "In Progress" does not fit in it; the glyph is already red, and the words are
                // one long-press away in the expanded view.
                if context.state.phase == .upcoming {
                    Text(context.state.startsAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .lineLimit(1)
                }
            } minimal: {
                SessionActivityGlyph(state: context.state)
            }
        }
    }
}

/// The Lock Screen and banner presentation.
///
/// Three lines, in the order every other family uses them: what weekend, what session, when.
private struct SessionActivityLockScreenView: View {
    let attributes: SessionActivityAttributes
    let state: SessionActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Space.xl) {
            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                Text(attributes.grandPrixName)
                    .font(.headline)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                Text(attributes.sessionName)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: Theme.Space.md)
            SessionActivityClock(state: state)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, Theme.Space.xxl)
        .padding(.vertical, Theme.Space.xl)
    }
}

/// When, in one line.
///
/// **Upcoming counts down; live does not count anything.** A running session's end is the grace
/// window's estimate until OpenF1 confirms the real one — the same estimate `SessionAlertPlanner`
/// places the safe-to-watch alert on, and roughly half an hour behind the fact. A clock ticking
/// down to a guess would read as "nearly over", which is a claim about the session this product
/// has no business making. `Strings.Schedule.inProgress` is what the app, the widget and the
/// accessory families all say instead, and this says it too.
private struct SessionActivityClock: View {
    let state: SessionActivityAttributes.ContentState

    var body: some View {
        switch state.phase {
        case .upcoming:
            Text(state.startsAt, style: .relative)
                .foregroundStyle(Theme.Palette.textPrimary)
        case .live:
            Text(NoSpoilersCore.Strings.Schedule.inProgress)
                .foregroundStyle(Theme.Palette.stateLive)
        }
    }
}

/// The one glyph the Dynamic Island's small presentations have room for.
///
/// Red while the session is running, which is the same signal `smallSessionTime` gives on the Home
/// Screen. The accessory widget families cannot do this — they render in `.accessory` vibrancy
/// mode, which flattens every colour into one material — but a Live Activity keeps its colours.
private struct SessionActivityGlyph: View {
    let state: SessionActivityAttributes.ContentState

    var body: some View {
        Image(systemName: Theme.Icon.sessionCountdown)
            .foregroundStyle(
                state.phase == .live ? Theme.Palette.stateLive : Theme.Palette.textSecondary
            )
    }
}
