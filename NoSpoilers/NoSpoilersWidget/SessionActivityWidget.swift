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
/// **What is drawn comes from `SessionActivityDisplay`, never from `context.state.phase` alone.**
/// The app cannot update this view from the background, so the phase it last pushed goes out of
/// date at the content's stale date — and until 2026-09-05 the view kept drawing it anyway, which
/// is how a Lock Screen came to say *In Progress* an hour after a session's grace window closed.
/// ActivityKit re-renders at the stale date with `context.isStale` set; every presentation below
/// folds that in before deciding what to show.
///
/// **The system's material, not ours.** Until 2026-09-06 this tinted the card with
/// `Theme.Palette.surface` and coloured its text with the palette too, and a Lock Screen showed the
/// Grand Prix's name in ivory on an ivory card: the system resolved the tint in one appearance and
/// the text in the other. A Live Activity is the one surface where the system owns the container,
/// so this no longer paints it, and the text takes the system's own styles for the same reason the
/// accessory families do. The brand red is the one fixed colour, on the wordmark and the live
/// state, and it reads on the Lock Screen's glass in either appearance.
///
/// **Schedule identity and a clock, arranged the way a broadcaster's card is.** Put next to the
/// BBC's football activity on the same Lock Screen, this had no identity and led with the words
/// *In Progress* at title size — the loudest element and the least informative. It now leads with
/// the wordmark and round, the flag and the Grand Prix, and a large clock: a countdown to the start
/// while the session is upcoming, and the time since a known start while it runs. Everything on it
/// is already on the Home Screen widget; this is a different arrangement of what is audited, not a
/// new place to put something.
struct SessionActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionActivityAttributes.self) { context in
            SessionActivityLockScreenView(
                attributes: context.attributes,
                state: context.state,
                display: context.display
            )
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    SessionActivitySessionLine(attributes: context.attributes, display: context.display)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    SessionActivityClock(state: context.state, display: context.display)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    SessionActivityWeekendLine(attributes: context.attributes)
                }
            } compactLeading: {
                SessionActivityGlyph(display: context.display)
            } compactTrailing: {
                // The compact slot is a few points wide. A clock fits it; "Finished" does not, and
                // the glyph's colour carries the state until the words are one long-press away.
                if context.display != .finished {
                    SessionActivityClock(state: context.state, display: context.display)
                        .font(.caption2.monospacedDigit())
                        .lineLimit(1)
                }
            } minimal: {
                SessionActivityGlyph(display: context.display)
            }
        }
    }
}

private extension ActivityViewContext<SessionActivityAttributes> {
    /// The pushed phase, advanced past the stale date. The one place `isStale` is read.
    var display: SessionActivityDisplay {
        SessionActivityDisplay(phase: state.phase, isStale: isStale)
    }
}

/// The weekend's flag, off `Theme.Header`'s ladder for the same reason the accessory families
/// take no `Canvas`: the Lock Screen's type is the system's to scale, and the card is not one of
/// the five surfaces the ladder was measured on. The macOS menu bar's 14pt flag is the precedent.
private let flagHeight: CGFloat = 16

/// Room for `H:MM:SS` at `.title2` semibold, and no more. See the clock's comment in
/// `SessionActivityLockScreenView` for what happens when the timer text is left to size itself.
private let clockMaxWidth: CGFloat = 104

/// The Lock Screen and banner presentation.
///
/// Three lines on the left, in the order every other family uses them — who we are, what weekend,
/// what session — and the clock on the right at a size that can be read from across a room.
private struct SessionActivityLockScreenView: View {
    let attributes: SessionActivityAttributes
    let state: SessionActivityAttributes.ContentState
    let display: SessionActivityDisplay

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Space.xl) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                HStack(spacing: Theme.Space.sm) {
                    NoSpoilersWordmark(size: .medium)
                    Text(NoSpoilersCore.Strings.Schedule.roundLabel(attributes.round))
                        .font(Theme.Typography.eyebrow)
                        .foregroundStyle(.secondary)
                }
                SessionActivityWeekendLine(attributes: attributes)
                SessionActivitySessionLine(attributes: attributes, display: display)
            }
            Spacer(minLength: Theme.Space.md)
            // Bounded, because `Text(timerInterval:)` asks for the width of the widest string it
            // could ever show and takes all of it: given priority it starved the left column to
            // `Bel…` and wrapped *In Progress* one syllable per line, and given `fixedSize` it
            // overflowed the card. The three lines on the left are the content; the clock gets
            // what a clock needs.
            SessionActivityClock(state: state, display: display)
                .font(.title2.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: clockMaxWidth, alignment: .trailing)
        }
        // The app's card insets, not a pair picked from the scale: this is a card at phone
        // scale on the same device as the app's, and the first cut sat 16 by 12 inside its
        // glass, visibly tighter than every card in the product. The corner and shadow are the
        // system's; only the breathing room is ours.
        .padding(.horizontal, card.horizontalPadding)
        .padding(.vertical, card.verticalPadding)
    }

    private var card: Theme.Card.Geometry { Theme.Card.geometry(.iosApp) }
}

/// Flag and Grand Prix, the way the medium widget's header puts them.
private struct SessionActivityWeekendLine: View {
    let attributes: SessionActivityAttributes

    var body: some View {
        HStack(spacing: Theme.Space.sm) {
            FlagImage(countryCode: attributes.countryCode, height: flagHeight)
            Text(attributes.grandPrixName)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }
}

/// The session, with its state beside it where the state is worth a word.
///
/// Live gets a red dot and `Strings.Schedule.inProgress`, which is what the app, the widget and
/// the accessory families say too. Finished is muted and says only that, because a finished
/// activity is still content on a locked screen the reader cannot decline. Upcoming says nothing
/// here: the clock is counting down, and that is the whole message.
private struct SessionActivitySessionLine: View {
    let attributes: SessionActivityAttributes
    let display: SessionActivityDisplay

    var body: some View {
        HStack(spacing: Theme.Space.sm) {
            Text(attributes.sessionName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            switch display {
            case .upcoming:
                EmptyView()
            case .live:
                HStack(spacing: Theme.Space.xs) {
                    Circle()
                        .fill(Theme.Palette.stateLive)
                        .frame(width: Theme.Space.sm, height: Theme.Space.sm)
                    Text(NoSpoilersCore.Strings.Schedule.inProgress)
                        .font(Theme.Typography.eyebrow)
                        .foregroundStyle(Theme.Palette.stateLive)
                }
            case .finished:
                Text(Strings.Sessions.finished)
                    .font(Theme.Typography.eyebrow)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// The clock, in one line.
///
/// **Upcoming counts down to the start; live counts up from it.** Both ends are known instants —
/// the start is the calendar's, and the elapsed time is arithmetic on it. What this still does not
/// do is count down to the *end* of a running session: that end is the grace window's estimate
/// until OpenF1 confirms the real one, roughly half an hour behind the fact, and a clock ticking
/// down to a guess would read as "nearly over", which is a claim about the session this product
/// has no business making. `SessionAlertPlanner` places the safe-to-watch alert on the same
/// estimate for the same reason.
///
/// `Text(timerInterval:)` rather than `Text(_:style: .timer)`: on the Lock Screen the latter came
/// out as *38 minutes* in words, at a width that truncated the Grand Prix beside it, where the
/// interval form is digits the system keeps ticking without the extension's help. The range's
/// far end is the phase's own instant — the start while upcoming, the effective end while live —
/// and the switch is on `display` rather than on the date because the stale-date re-render is
/// what moves the phase on, and the clock has to agree with the line beside it.
///
/// **Finished shows nothing.** The elapsed time of a session that is over is a duration, and
/// durations are where the finished badge went wrong before (`Finished 4166h`); the word is on the
/// session line and that is enough.
private struct SessionActivityClock: View {
    let state: SessionActivityAttributes.ContentState
    let display: SessionActivityDisplay

    var body: some View {
        switch display {
        case .upcoming:
            // The lower bound only shapes a progress view this never draws; it has to be in the
            // past for the text to count, and the look-ahead is the furthest away a start can be.
            Text(timerInterval: state.startsAt.addingTimeInterval(-SessionActivityAttributes.lookAhead)...state.startsAt,
                 countsDown: true)
                .foregroundStyle(.primary)
        case .live:
            Text(timerInterval: state.startsAt...state.endsAt, countsDown: false)
                .foregroundStyle(.primary)
        case .finished:
            EmptyView()
        }
    }
}

/// The one glyph the Dynamic Island's small presentations have room for.
///
/// Red while the session is running, which is the same signal `smallSessionTime` gives on the Home
/// Screen, and back to the system's secondary colour once it is over. The accessory widget families
/// cannot do this — they render in `.accessory` vibrancy mode, which flattens every colour into one
/// material — but a Live Activity keeps its colours.
private struct SessionActivityGlyph: View {
    let display: SessionActivityDisplay

    var body: some View {
        Image(systemName: Theme.Icon.sessionCountdown)
            .foregroundStyle(display == .live ? AnyShapeStyle(Theme.Palette.stateLive) : AnyShapeStyle(.secondary))
    }
}
