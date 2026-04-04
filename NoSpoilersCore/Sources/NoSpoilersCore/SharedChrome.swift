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
    case small

    var frame: CGSize {
        switch self {
        case .large:
            return CGSize(width: 72, height: 18)
        case .medium:
            return CGSize(width: 48, height: 12)
        case .small:
            return CGSize(width: 68, height: 17)
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

public struct NoSpoilersWordmark: View {
    private let size: NoSpoilersWordmarkSize

    public init(size: NoSpoilersWordmarkSize = .large) {
        self.size = size
    }

    public var body: some View {
        Image("f1logo", bundle: noSpoilersCoreBundle)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(BrandPalette.signalRed)
            .frame(width: size.frame.width, height: size.frame.height)
    }
}

public struct NoSpoilersRoundPill: View {
    private let text: Text

    public init(_ text: String) {
        self.text = Text(verbatim: text)
    }

    public init(_ key: LocalizedStringKey) {
        self.text = Text(key)
    }

    public var body: some View {
        text
            .font(.caption2.weight(.semibold))
            .foregroundStyle(BrandPalette.signalRed)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(BrandPalette.blush.opacity(0.7))
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
                .foregroundStyle(BrandPalette.finishedGrey)
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
                .foregroundStyle(BrandPalette.upcomingAmber)
                .padding(.horizontal, compact ? 8 : 10)
                .padding(.vertical, compact ? 4 : 6)
                .background(BrandPalette.upcomingAmber.opacity(0.12))
                .clipShape(Capsule())
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
