import SwiftUI

public enum NoSpoilersCardDensity {
    case regular
    case compact
    case widget

    var cornerRadius: CGFloat {
        switch self {
        case .regular:
            return 24
        case .compact:
            return 18
        case .widget:
            return 14
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .regular:
            return 20
        case .compact:
            return 16
        case .widget:
            return 12
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .regular:
            return 20
        case .compact:
            return 14
        case .widget:
            return 10
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .regular:
            return 20
        case .compact:
            return 14
        case .widget:
            return 10
        }
    }

    var shadowYOffset: CGFloat {
        switch self {
        case .regular:
            return 12
        case .compact:
            return 8
        case .widget:
            return 6
        }
    }

    var fillOpacity: Double {
        switch self {
        case .regular:
            return 0.82
        case .compact:
            return 0.78
        case .widget:
            return 0.74
        }
    }
}

public enum NoSpoilersBadgeStyle {
    case finished
    case live
    case upcoming
}

public enum NoSpoilersWordmarkSize {
    case large
    case medium

    /// `.medium` is deliberately small. It shares a 300pt-wide row in the macOS
    /// popover with the centred Grand Prix name, and type is wider than the
    /// image it replaced: at 9pt the wordmark measures 71.5pt against the old
    /// logo's 48pt, which keeps every calendar name except
    /// "Barcelona-Catalunya Grand Prix" on one line. That one wrapped before
    /// this change too.
    var fontSize: CGFloat {
        switch self {
        case .large:
            return 15
        case .medium:
            return 9
        }
    }

    var tracking: CGFloat {
        switch self {
        case .large:
            return 1.4
        case .medium:
            return 0.6
        }
    }
}

public struct NoSpoilersBackground: View {
    public init() {}

    public var body: some View {
        LinearGradient(
            colors: [BrandPalette.ivory, BrandPalette.blush.opacity(0.72), Color.white],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

public struct NoSpoilersCard<Content: View>: View {
    private let density: NoSpoilersCardDensity
    private let content: Content

    public init(
        density: NoSpoilersCardDensity = .regular,
        @ViewBuilder content: () -> Content
    ) {
        self.density = density
        self.content = content()
    }

    public var body: some View {
        content
            .padding(.horizontal, density.horizontalPadding)
            .padding(.vertical, density.verticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: density.cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(density.fillOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: density.cornerRadius, style: .continuous)
                    .stroke(BrandPalette.mistGrey.opacity(0.55), lineWidth: 1)
            )
            .shadow(
                color: BrandPalette.deepMaroon.opacity(density == .widget ? 0.06 : 0.08),
                radius: density.shadowRadius,
                x: 0,
                y: density.shadowYOffset
            )
    }
}

/// The product's own wordmark: the app name set in brand red.
///
/// It is type rather than an image so that there is no mark to license, and so
/// that the name in the header is the same string as the name everywhere else —
/// `Strings.AppInfo.name`, uppercased for display only.
public struct NoSpoilersWordmark: View {
    private let size: NoSpoilersWordmarkSize

    public init(size: NoSpoilersWordmarkSize = .large) {
        self.size = size
    }

    public var body: some View {
        Text(Strings.AppInfo.name)
            .textCase(.uppercase)
            .font(.system(size: size.fontSize, weight: .heavy))
            .tracking(size.tracking)
            .foregroundStyle(BrandPalette.signalRed)
            .fixedSize()
    }
}

public struct NoSpoilersRoundPill: View {
    private let text: Text
    private let isFinished: Bool

    public init(_ text: String, isFinished: Bool = false) {
        self.text = Text(verbatim: text)
        self.isFinished = isFinished
    }

    public init(_ key: LocalizedStringKey, isFinished: Bool = false) {
        self.text = Text(key)
        self.isFinished = isFinished
    }

    public var body: some View {
        text
            .font(.caption2.weight(.semibold))
            .foregroundStyle(isFinished ? Theme.Palette.stateFinished : BrandPalette.signalRed)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(isFinished ? Theme.Palette.stateFinished.opacity(0.12) : BrandPalette.blush.opacity(0.7))
            .clipShape(Capsule())
    }
}

public struct NoSpoilersStatusBadge: View {
    private let text: Text
    private let style: NoSpoilersBadgeStyle
    private let compact: Bool

    public init(text: Text, style: NoSpoilersBadgeStyle, compact: Bool = false) {
        self.text = text
        self.style = style
        self.compact = compact
    }

    public init(text: String, style: NoSpoilersBadgeStyle, compact: Bool = false) {
        self.text = Text(verbatim: text)
        self.style = style
        self.compact = compact
    }

    public init(textKey: LocalizedStringKey, style: NoSpoilersBadgeStyle, compact: Bool = false) {
        self.text = Text(textKey)
        self.style = style
        self.compact = compact
    }

    public var body: some View {
        switch style {
        case .finished:
            text
                .font((compact ? Font.caption2 : .caption).weight(.medium))
                .foregroundStyle(Theme.Palette.stateFinished)
        case .live:
            text
                .font((compact ? Font.caption2 : .caption).weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, compact ? 8 : 10)
                .padding(.vertical, compact ? 4 : 6)
                .background(BrandPalette.signalRed)
                .clipShape(Capsule())
        case .upcoming:
            text
                .font((compact ? Font.caption2 : .caption).weight(.medium))
                .foregroundStyle(Theme.Palette.stateUpcoming)
                .padding(.horizontal, compact ? 8 : 10)
                .padding(.vertical, compact ? 4 : 6)
                .background(Theme.Palette.stateUpcoming.opacity(0.12))
                .clipShape(Capsule())
        }
    }
}

/// The line under a weekend's name: which round it is, where it is, and when.
///
/// **This is the part of the weekend header that actually repeated.** The three
/// headers around it — `NoSpoilers/ContentView.swift`,
/// `NoSpoilersMac/ContentView.swift` and the widget's — arrange their wordmark,
/// name and flag three different ways on purpose, and folding those into one
/// component would have produced a switch with four bodies rather than a shared
/// design. This line was written out three times with the same structure and
/// three sets of fonts, and that is a copy.
///
/// **Not drawn on the compact widget families.** Their header is one line with
/// no room for a location, so the tokens this uses trap on `.widgetSmall` and
/// `.widgetMedium` rather than inventing sizes for a line that does not exist.
public struct NoSpoilersWeekendMeta: View {
    private let canvas: Theme.Canvas
    private let round: Int
    private let isFinished: Bool
    private let location: String
    private let dateRange: String?

    /// `dateRange` is `nil` when the weekend has no sessions to span — a real
    /// schedule state, not a missing value, and the reason this line can be
    /// drawn as a round pill and a place name alone.
    public init(
        canvas: Theme.Canvas,
        round: Int,
        isFinished: Bool = false,
        location: String,
        dateRange: String?
    ) {
        self.canvas = canvas
        self.round = round
        self.isFinished = isFinished
        self.location = location
        self.dateRange = dateRange
    }

    public var body: some View {
        HStack(alignment: .center, spacing: Theme.Header.metaSpacing(canvas)) {
            NoSpoilersRoundPill(Strings.Schedule.roundLabel(round), isFinished: isFinished)

            Text(location)
                .font(Theme.Typography.weekendLocation(canvas))
                .foregroundStyle(Theme.Palette.textSecondary)

            Spacer(minLength: 0)

            if let dateRange {
                Text(dateRange)
                    .font(Theme.Typography.weekendDateRange(canvas))
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
        }
        .lineLimit(Theme.Row.labelLineLimit(canvas))
    }
}

/// The weekend after this one: an eyebrow, a flag, the weekend's name over an
/// optional detail line, and whatever the surface wants trailing.
///
/// **This replaced four implementations** — `NoSpoilers/ContentView.swift`'s
/// `nextWeekendCard`, `NoSpoilersMac/ContentView.swift`'s `nextRoundFooter`, and
/// both branches of the widget's `widgetComingUp`. All four drew the same row:
/// flag, name stack, spacer, one trailing element.
///
/// **The extra-large widget's version was not one of them and stays where it
/// is.** That one is a 140pt sidebar column — eyebrow, then the flag on its own
/// line, then the name over a pill-and-location row over the countdown. Sharing
/// a component with it would mean a second body inside this one, which is the
/// thing the convergence is trying to remove.
///
/// **Two disagreements had to be settled to get here.** The large widget drew
/// its eyebrow *inside* the name stack, to the right of the flag, where iOS and
/// macOS drew it above the whole row; above won, on two sites against one. And
/// the widget painted the eyebrow `signalRed` where the apps painted it
/// tertiary; tertiary won, because red is this app's live-session signal —
/// `Palette.state` and the small widget's in-progress line both use it — and a
/// weekend that has not started yet is the precise opposite of live.
public struct NoSpoilersNextUpFooter<Trailing: View>: View {
    private let canvas: Theme.Canvas
    private let countryCode: String?
    private let name: Text
    private let detail: Text?
    private let trailing: Trailing

    public init(
        canvas: Theme.Canvas,
        countryCode: String?,
        name: Text,
        detail: Text? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.canvas = canvas
        self.countryCode = countryCode
        self.name = name
        self.detail = detail
        self.trailing = trailing()
    }

    @ViewBuilder
    public var body: some View {
        if Theme.NextUp.showsLabel(canvas) {
            VStack(alignment: .leading, spacing: Theme.NextUp.labelGap(canvas)) {
                Text(Strings.Schedule.comingUp)
                    .font(Theme.Typography.eyebrow)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .textCase(.uppercase)

                row
            }
        } else {
            row
        }
    }

    private var row: some View {
        HStack(spacing: Theme.NextUp.contentSpacing(canvas)) {
            FlagImage(countryCode: countryCode, height: Theme.NextUp.flagHeight(canvas))

            VStack(alignment: .leading, spacing: Theme.Row.labelSpacing(canvas)) {
                name
                    .font(Theme.Typography.nextUpName(canvas))
                    .foregroundStyle(Theme.Palette.textPrimary)

                if let detail {
                    detail
                        .font(Theme.Typography.nextUpDetail(canvas))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            .lineLimit(Theme.Row.labelLineLimit(canvas))

            Spacer(minLength: 0)

            trailing
        }
    }
}

/// One session in a list: an accent rule in the session's state colour, its
/// name, an optional second line, and whatever the surface wants trailing.
///
/// **This replaced four implementations** — `NoSpoilers/ContentView.swift`,
/// `NoSpoilersMac/ContentView.swift`, and both of the widget's, which drew the
/// same row twice under `widgetSessionRow` and `smallSessionRow`. They agreed on
/// the shape and disagreed on nearly every number in it, including a 10pt corner
/// radius on iOS against 8pt in the other two for the same surface.
///
/// **What varies is `canvas`; what varies by caller is content.** The four rows
/// put genuinely different things on the second line — an absolute date on iOS
/// and macOS, a secondary session name in the medium widget, a relative time in
/// the small one — and genuinely different things in the trailing slot, from a
/// badge with a live countdown to nothing at all. Those stay with the callers,
/// which is what makes one component possible: the parts that differ were never
/// the geometry.
///
/// `detail` and `trailing` are both optional in effect — `.widgetLarge` has no
/// second line at all, and `.widgetSmall` has no trailing badge.
public struct NoSpoilersSessionRow<Trailing: View>: View {
    private let canvas: Theme.Canvas
    private let status: SessionStatus
    private let name: Text
    private let detail: Text?
    private let trailing: Trailing

    public init(
        canvas: Theme.Canvas,
        status: SessionStatus,
        name: Text,
        detail: Text? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.canvas = canvas
        self.status = status
        self.name = name
        self.detail = detail
        self.trailing = trailing()
    }

    @ViewBuilder
    public var body: some View {
        if let surface = Theme.Row.surface(canvas) {
            content
                .padding(.horizontal, surface.horizontalPadding)
                .padding(.vertical, surface.verticalPadding)
                .background(
                    RoundedRectangle(cornerRadius: surface.cornerRadius, style: .continuous)
                        .fill(Theme.Palette.surfaceRaised)
                )
        } else {
            content
        }
    }

    private var content: some View {
        HStack(alignment: .center, spacing: Theme.Row.contentSpacing(canvas)) {
            RoundedRectangle(cornerRadius: Theme.Radius.hairline)
                .fill(Theme.Palette.state(status))
                .frame(width: Theme.Row.accentWidth, height: Theme.Row.accentHeight(canvas))

            VStack(alignment: .leading, spacing: Theme.Row.labelSpacing(canvas)) {
                name
                    .font(Theme.Typography.rowLabel(canvas))
                    .foregroundStyle(Theme.Palette.textPrimary)

                // `Theme.Typography.rowDetail` traps on `.widgetLarge`, which is
                // safe only because that canvas never passes a detail. Keep it
                // inside the `if let`.
                if let detail {
                    detail
                        .font(Theme.Typography.rowDetail(canvas))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            .lineLimit(Theme.Row.labelLineLimit(canvas))
            .frame(minWidth: Theme.Row.labelMinWidth(canvas), alignment: .leading)

            Spacer(minLength: Theme.Space.md)

            trailing
        }
    }
}

extension NoSpoilersSessionRow where Trailing == EmptyView {
    /// A row with nothing trailing — the small widget's single hero row, which
    /// puts its state on the detail line instead of in a badge.
    public init(
        canvas: Theme.Canvas,
        status: SessionStatus,
        name: Text,
        detail: Text? = nil
    ) {
        self.init(canvas: canvas, status: status, name: name, detail: detail) {
            EmptyView()
        }
    }
}

public struct NoSpoilersMessageCard: View {
    private let iconName: String
    private let title: Text
    private let bodyText: Text
    private let density: NoSpoilersCardDensity

    public init(
        iconName: String = "flag.checkered.2.crossed",
        title: Text,
        bodyText: Text,
        density: NoSpoilersCardDensity = .regular
    ) {
        self.iconName = iconName
        self.title = title
        self.bodyText = bodyText
        self.density = density
    }

    public var body: some View {
        NoSpoilersCard(density: density) {
            VStack(spacing: density == .widget ? 8 : 12) {
                Image(systemName: iconName)
                    .font(.system(size: density == .widget ? 28 : 34))
                    .foregroundStyle(BrandPalette.signalRed)
                title
                    .font(.headline)
                    .foregroundStyle(BrandPalette.smoke)
                bodyText
                    .font(density == .widget ? .caption : .subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(BrandPalette.secondaryText)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
