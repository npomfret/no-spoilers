import SwiftUI

/// The design tokens every target draws from, so that a reskin is an edit here
/// rather than a search across four files.
///
/// **Rebuild-time, not runtime.** These are public static constants in the shape
/// `BrandPalette` already established — no environment plumbing. A theme change
/// is an edit to these values and a new build, which is what lets the menu bar
/// label (an `NSHostingView` built by an `AppDelegate`) and the widget (a
/// separate process with no app environment to inherit) get the same answer as
/// the app without anything being injected at three separate roots.
///
/// `BrandPalette` remains the colour source of truth and is not folded in here.
/// `Theme.Palette` names roles that point at it — "what colour is a finished
/// session", not "what is signal red" — so there is still one place a hex lives.
public enum Theme {
    /// What each colour is *for*, as opposed to what it is.
    ///
    /// `BrandPalette` answers "what is signal red"; this answers "what colour is
    /// a finished session". Every role below resolves to a `BrandPalette` entry
    /// or a literal already on screen — the palette stays the source of truth
    /// and nothing here introduces a new colour.
    ///
    /// **One value per role, and no variant mechanism.** Dark mode is not being
    /// built: both hosted surfaces force `.preferredColorScheme(.light)` and the
    /// widget's container background is a hardcoded light gradient. The roles
    /// exist anyway because they are a reskin blocker on their own — a system
    /// colour does not move when the palette moves, which is the entire problem.
    /// Naming them now is what makes adding dark mode later "give each role a
    /// second value" instead of "find every colour decision again". Do not build
    /// machinery here to hold values nobody has chosen.
    ///
    /// **These roles are not a pure transcription, and the difference is
    /// macOS.** iOS and the shared components already draw text in `smoke`,
    /// `secondaryText` and `tertiaryText`, so for them the sweep is a rename.
    /// The macOS popover and `AboutView` instead use the system's `.primary`,
    /// `.secondary` and `.tertiary` at 22 sites, and those are *not* the same
    /// colours — a system label is neutral where `smoke` is warm. Moving them
    /// onto these roles changes what is on screen, by a little, on macOS. That
    /// is a sweep-with-screenshots change, not a phase-1 one.
    ///
    /// Those same 22 sites are why the two `.preferredColorScheme(.light)` calls
    /// exist: the gradient behind them is hardcoded light, so the system colours
    /// have to be pinned to match it. Naming the roles is what eventually lets
    /// that pinning go.
    public enum Palette {
        public static let textPrimary = BrandPalette.smoke
        public static let textSecondary = BrandPalette.secondaryText
        public static let textTertiary = BrandPalette.tertiaryText

        /// Dividers and hairline structure.
        public static let separator = BrandPalette.mistGrey

        /// The page behind everything. `brand.md` prefers ivory over pure white.
        public static let surface = BrandPalette.ivory

        /// A row or panel lifted off `surface` — the session-row fill, at four
        /// sites across three targets.
        ///
        /// **The card fill is not this.** `NoSpoilersCardDensity` resolves it to
        /// 0.82/0.78/0.74 from its density axis, so a card sits slightly more
        /// opaque than a row and does so on purpose. Restating either here would
        /// give one surface two answers.
        public static let surfaceRaised = Color.white.opacity(0.65)

        /// The three session states, resolved once so that the accent bar and
        /// the badge cannot disagree — which they did, three different ways
        /// across three targets, including a macOS row that drew a blue bar
        /// beside an amber pill for the same session.
        ///
        /// Green and blue are what `docs/brand.md` specifies and what macOS and
        /// the widget already drew; iOS was the outlier. `finishedGrey` and
        /// `upcomingAmber` are gone.
        ///
        /// **These colour the bar and the badge, and nothing else.** Session
        /// names stay on `textPrimary` in every state, which is a contrast
        /// decision rather than an aesthetic one — measured with the WCAG sRGB
        /// formula, `successGreen` is 3.31:1 on ivory and 3.43:1 on
        /// `surfaceRaised`. That clears the 3:1 bar for UI components and large
        /// text, which is what a 3pt bar and a badge are, and misses the 4.5:1
        /// bar for body text, which is what a session name is. Painting names
        /// green would have taken the widget from 16.25:1 down to 3.31:1 — the
        /// one real regression the change offered, now declined.
        ///
        /// The alternative was a darker `#278253` for text; it was not needed
        /// once names stayed put, so no new palette entry exists. **Do not draw
        /// `stateFinished` on `blush`** — 2.60:1 there fails even the 3:1 bar.
        public static let stateFinished = BrandPalette.successGreen
        public static let stateLive = BrandPalette.signalRed
        public static let stateUpcoming = BrandPalette.upcomingBlue

        /// The one place a session's status becomes a colour.
        ///
        /// It replaced three: an iOS `statusColor`, a macOS inline ternary, and
        /// the widget's `accentColor`, which disagreed on both hue and opacity —
        /// finished was `finishedGrey` on iOS, `successGreen.opacity(0.6)` on
        /// macOS and `successGreen.opacity(0.75)` in the widget. Nobody chose
        /// those opacities; they collapse to one value here.
        public static func state(_ status: SessionStatus) -> Color {
            switch status {
            case .finished:   return stateFinished
            case .inProgress: return stateLive
            case .upcoming:   return stateUpcoming
            }
        }
    }

    /// Where a piece of UI is being drawn — the axis every other token varies
    /// along.
    ///
    /// **Why five cases rather than the three `NoSpoilersCardDensity` has.**
    /// That enum resolves card geometry from regular/compact/widget, and it is
    /// the seed this whole file grew from. But it cannot carry type as well,
    /// because the widget's medium and large families share one card geometry
    /// and deliberately do *not* share a type size: `widgetSessionRow` draws its
    /// label at `.caption` in medium and `.subheadline` in large, threaded
    /// through as a separate `compact: Bool`. Two axes, one of them a `Bool`,
    /// for one idea.
    ///
    /// A case per surface holds both without duplicating either — `widgetMedium`
    /// and `widgetLarge` return the same radius and different fonts, and nothing
    /// has to be said twice. It also gives `widgetSmall` a name; today it is a
    /// family with its own private row implementation and no way to refer to it.
    ///
    /// **The conflict is latent, not theoretical.** `NoSpoilersCardDensity.widget`
    /// is unreachable right now — the widget target uses neither `NoSpoilersCard`
    /// nor `NoSpoilersMessageCard`, so those five values are dead. It goes live
    /// the moment the widget's two empty states move onto `NoSpoilersMessageCard`,
    /// and that is when one 3-case axis would have had to answer for both widget
    /// families at once.
    ///
    /// **Named `Canvas`, not `Surface`,** because `Theme.Palette.surface` is
    /// already a colour. One word meaning both "a place UI is drawn" and "the
    /// background behind it" inside one namespace is a trip hazard, and the
    /// colour spelling is the one worth keeping — it is what CSS and the wider
    /// design-system vocabulary use.
    ///
    /// `NoSpoilersCardDensity` still owns card geometry and is not folded in
    /// here yet; that fold is a change to a live component rather than an
    /// addition, so it travels with the components it changes.
    public enum Canvas: CaseIterable {
        /// The iOS app's paged weekend cards.
        case iosApp
        /// The macOS menu bar popover.
        case macPopover
        /// `systemSmall` — one hero name and a single flat session row.
        case widgetSmall
        /// `systemMedium` — header plus two rows.
        case widgetMedium
        /// `systemLarge` and `systemExtraLarge`, which share a scale.
        case widgetLarge
    }

    /// The type scale, resolved per `Canvas`.
    ///
    /// **Named `Typography` rather than `Type`** because `Theme.Type` already
    /// means something in Swift — the metatype of `Theme` — and a nested enum by
    /// that name would need backticks at every use.
    ///
    /// Every value below is transcribed from a real call site; none is
    /// interpolated to fill a gap. Roles are added here as each one is confirmed
    /// to exist on all five canvases, which is why there are two so far and not
    /// the eight the `.font(…)` count might suggest.
    public enum Typography {
        /// The Grand Prix name in a header.
        ///
        /// **`widgetSmall` is larger than `widgetLarge`, and that is correct.**
        /// In the small family the name is the hero and fills the widget; in the
        /// large family it is a heading above a session list. Read as a ladder
        /// it looks like a mistake, which is exactly why it is written down.
        public static func weekendTitle(_ canvas: Canvas) -> Font {
            switch canvas {
            case .iosApp:       return .title2.weight(.bold)
            case .macPopover:   return .headline.weight(.semibold)
            case .widgetSmall:  return .title3.weight(.bold)
            case .widgetMedium: return .caption.weight(.bold)
            case .widgetLarge:  return .subheadline.weight(.semibold)
            }
        }

        /// A session's name in a session row.
        ///
        /// **`macPopover` is an absolute 13pt and the only value here that does
        /// not scale with Dynamic Type.** Transcribing it keeps the popover
        /// rendering exactly as it does today; moving it to a semantic font is a
        /// visible change and an accessibility one, so it is the sweep's
        /// decision to make with a screenshot, not this file's.
        ///
        /// **`widgetSmall` and `widgetMedium` differ only in weight** — semibold
        /// against medium at the same `.caption` size. No reason for that has
        /// been found; it reads as drift, and naming both is what makes it
        /// visible enough to settle.
        public static func rowLabel(_ canvas: Canvas) -> Font {
            switch canvas {
            case .iosApp:       return .body.weight(.semibold)
            case .macPopover:   return .system(size: 13, weight: .medium)
            case .widgetSmall:  return .caption.weight(.semibold)
            case .widgetMedium: return .caption.weight(.medium)
            case .widgetLarge:  return .subheadline.weight(.medium)
            }
        }
    }

    /// The spacing rhythm: gaps between things, and the space around them.
    ///
    /// **These are the values already on screen, not a scale anyone designed.**
    /// Counted across `NoSpoilers/` and `NoSpoilersCore/Sources/` on 2026-08-17,
    /// the 123 spacing and padding literals land almost entirely on a 2pt grid:
    /// the eight steps below carry 103 of them. Naming them changes nothing
    /// today; it is what makes changing them later a single edit.
    ///
    /// **Zero is deliberately not a step.** `spacing: 0` appears 9 times and
    /// means "no gap" — an override of SwiftUI's default rather than a value on
    /// the rhythm. It does not move when the scale moves, so it stays a literal.
    ///
    /// **Eleven strays do not fit the grid** and will each have to round to a
    /// neighbouring step when the call sites are swept onto these names: 1pt
    /// (2 sites), 3pt (3), 7pt (2), 9pt (2), and 14pt (2). Rounding them is a
    /// visible change of a point or two, so it belongs to the sweep with the
    /// screenshots that go with it — not to this file.
    public enum Space {
        public static let xxs: CGFloat = 2
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 6
        public static let md: CGFloat = 8
        public static let lg: CGFloat = 10
        public static let xl: CGFloat = 12
        public static let xxl: CGFloat = 16
        public static let xxxl: CGFloat = 20
    }

    /// Corner radii for everything that is not a card.
    ///
    /// All four values are already on the same 2pt grid as `Space`, so unlike
    /// the spacing above there is nothing here that has to round.
    ///
    /// **The card radii are not here.** `NoSpoilersCardDensity` resolves 24/18/14
    /// from its regular/compact/widget axis and is the one piece of this whole
    /// system that already works. Restating those numbers here would make two
    /// answers to one question, which is the problem this file exists to remove;
    /// the density axis gets folded into `Theme` as a whole, later, rather than
    /// copied into it now.
    public enum Radius {
        /// The session accent bar — a 3pt-wide vertical rule. Four sites across
        /// three targets, all agreeing.
        public static let hairline: CGFloat = 2
        /// The macOS menu row hover highlight.
        public static let small: CGFloat = 6
        /// The session row on macOS and in the widget.
        public static let medium: CGFloat = 8
        /// The session row on iOS — the same surface as `medium`, drawn 2pt
        /// rounder. Nobody decided that; converging the four session-row
        /// implementations is what settles which of the two survives.
        public static let large: CGFloat = 10
    }

    /// How fast the product feels.
    ///
    /// **Every one of these is a macOS site today** — the hover and press
    /// transitions on the menu row button style, and the "Copied!" flash on the
    /// update banner. Nothing on iOS or in the widget animates at all, and the
    /// iOS pager deliberately runs its own interactive transition rather than an
    /// `.animation(_:value:)` (see `NoSpoilers/ContentView.swift`).
    ///
    /// So this is a vocabulary of four with three speakers, which is worth
    /// naming precisely because the next thing that wants to animate should be
    /// choosing from a list rather than typing a number.
    public enum Motion {
        /// Pointer entering or leaving a menu row.
        public static let hover: Animation = .easeInOut(duration: 0.12)
        /// Press-down feedback — faster than `hover`, because a press should
        /// feel like it has already happened.
        public static let press: Animation = .easeInOut(duration: 0.08)
        /// A control confirming it did the thing: the copy button turning green.
        public static let confirm: Animation = .easeInOut(duration: 0.15)
        /// How long a confirmation stays up before reverting. Distinct from
        /// `confirm`, which is how long the change itself takes to draw — the
        /// two were 0.15 and 2 seconds sitting 270 lines apart with nothing
        /// saying they were related.
        public static let confirmationHold: TimeInterval = 2
    }

    /// Every symbol the product draws, named for what it means rather than what
    /// it looks like.
    ///
    /// Swapping symbol sets is otherwise a grep for string literals across four
    /// files — and `flagFallback` is exactly the entry that grep misses, because
    /// it is not a symbol name at all. It is the one below that would have been
    /// left behind.
    ///
    /// **Swift-only.** SF Symbols have no CSS equivalent, so this family is one
    /// of the tokens that cannot cross to the website.
    ///
    /// **Asset names are not here yet**, though `"nospoilers-icon"` is written
    /// out at three sites and `"flag-\(code)"` at one. Those three sites reach
    /// the same asset through two different bundle spellings — `.module` from
    /// inside this package, `noSpoilersCoreBundle` from the macOS target — and
    /// naming the string without settling the bundle would hide half the
    /// duplication rather than remove it. It goes with the screen-header
    /// convergence, which is where both spellings meet.
    public enum Icon {
        /// Marks the gap between seasons. Three sites: the widget's off-season
        /// view, the macOS message card, and the default for
        /// `NoSpoilersMessageCard`.
        public static let offSeason = "flag.checkered.2.crossed"
        /// The schedule could not be loaded — a failure, not an empty calendar.
        public static let scheduleUnavailable = "calendar.badge.exclamationmark"
        /// The Home Screen widget itself, on the iOS install prompt.
        public static let widget = "square.grid.2x2.fill"
        /// Jump the pager back to the weekend happening now.
        public static let currentWeekend = "location.fill"
        public static let about = "info.circle"
        public static let website = "globe"
        public static let settings = "gear"
        public static let quit = "power"
        /// A newer build is available on the Homebrew tap.
        public static let updateAvailable = "arrow.up.circle.fill"

        /// Drawn when a country has no flag asset — **an emoji, not a symbol**,
        /// which is why it belongs here rather than being left where a symbol
        /// sweep would never find it.
        public static let flagFallback = "🏁"
    }
}
