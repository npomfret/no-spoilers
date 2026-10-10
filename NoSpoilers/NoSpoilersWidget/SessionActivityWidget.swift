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
/// the wordmark and round, the flag and the Grand Prix, and a large clock: a countdown to the
/// scheduled start while upcoming, then the labelled scheduled time. Everything on it
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
                    NoSpoilersWordmark(size: .medium)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    SessionActivityClock(state: context.state, display: context.display)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: Theme.Space.xs) {
                        SessionActivityWeekendLine(attributes: context.attributes)
                        SessionActivitySessionLine(attributes: context.attributes, display: context.display)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                SessionActivityMark()
            } compactTrailing: {
                switch context.display {
                case .upcoming:
                    SessionActivityClock(state: context.state, display: context.display)
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .lineLimit(1)
                        // A timer otherwise requests the width of its entire possible range.
                        // This fits H:MM:SS and keeps the island from claiming unused space.
                        .frame(width: compactClockWidth, alignment: .trailing)
                        .accessibilityLabel(Strings.Sessions.countdownToScheduledStart)
                case .live, .unconfirmed:
                    SessionActivityStatusGlyph(display: context.display)
                }
            } minimal: {
                SessionActivityMark()
                    .overlay(alignment: .bottomTrailing) {
                        if context.display == .unconfirmed {
                            SessionActivityStatusGlyph(display: context.display)
                                .font(.caption2.weight(.semibold))
                                .background(.black, in: Circle())
                        }
                    }
            }
        }
    }
}

private extension ActivityViewContext<SessionActivityAttributes> {
    /// The pushed phase, marked unconfirmed past the stale date. The one place `isStale` is read.
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

/// The compact timer has one small slot beside the camera; details belong in the expanded view.
private let compactClockWidth: CGFloat = 48

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
/// The scheduled window and an unconfirmed finish are labelled explicitly. Upcoming says nothing
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
                Text(NoSpoilersCore.Strings.Schedule.inProgress)
                    .font(Theme.Typography.eyebrow)
                    .foregroundStyle(.secondary)
            case .unconfirmed:
                Text(NoSpoilersCore.Strings.Schedule.finishUnconfirmed)
                    .font(Theme.Typography.eyebrow)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Upcoming counts down to the scheduled start. After that, the clock shows the labelled scheduled
/// start time. It never presents a calendar estimate as measured race duration or a finish.
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
        case .live, .unconfirmed:
            VStack(alignment: .trailing, spacing: Theme.Space.xs) {
                Text(Strings.Sessions.scheduledStart)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(state.startsAt, style: .time)
                    .foregroundStyle(.primary)
            }
        }
    }
}

/// The existing red-and-white artwork on the island's black ground, without an app-icon container.
private struct SessionActivityMark: View {
    var body: some View {
        Image(Theme.Icon.appIcon, bundle: noSpoilersCoreBundle)
            .resizable()
            .scaledToFit()
            // The artwork has transparent margins. A 32pt asset leaves its visible mark about
            // 26pt across, inside the minimal island's 36pt height without clipping the artwork.
            .frame(width: 32, height: 32)
            .accessibilityLabel(NoSpoilersCore.Strings.AppInfo.name)
    }
}

/// Calendar timing cannot confirm a running session. Neutral shapes distinguish schedule and
/// uncertainty; red belongs to the app mark, not to a claim of live racing.
private struct SessionActivityStatusGlyph: View {
    let display: SessionActivityDisplay

    var body: some View {
        switch display {
        case .upcoming:
            Image(systemName: Theme.Icon.sessionCountdown)
                .foregroundStyle(.secondary)
                .accessibilityLabel(Strings.Sessions.countdownToScheduledStart)
        case .live:
            Image(systemName: Theme.Icon.sessionScheduled)
                .foregroundStyle(.secondary)
                .accessibilityLabel(NoSpoilersCore.Strings.Schedule.inProgress)
        case .unconfirmed:
            Image(systemName: Theme.Icon.sessionUnconfirmed)
                .foregroundStyle(.secondary)
                .accessibilityLabel(NoSpoilersCore.Strings.Schedule.finishUnconfirmed)
        }
    }
}
