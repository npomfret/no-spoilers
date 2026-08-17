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
        /// **The card fill is not this.** `Theme.Card` resolves it to
        /// 0.82/0.78/0.74 per canvas, so a card sits slightly more opaque than a
        /// row and does so on purpose. Restating either here would give one
        /// surface two answers.
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
    /// **Why five cases rather than the three `NoSpoilersCardDensity` had.**
    /// That enum resolved card geometry from regular/compact/widget, and it is
    /// the seed this whole file grew from. But it could not carry type as well,
    /// because the widget's medium and large families share one card geometry
    /// and deliberately do *not* share a type size: `widgetSessionRow` draws its
    /// label at `.caption` in medium and `.subheadline` in large, threaded
    /// through as a separate `compact: Bool`. Two axes, one of them a `Bool`,
    /// for one idea.
    ///
    /// A case per surface holds both without duplicating either — `widgetMedium`
    /// and `widgetLarge` return the same radius and different fonts, and nothing
    /// has to be said twice. It also gives `widgetSmall` a name; before this axis
    /// it was a family with its own private row implementation and no way to
    /// refer to it.
    ///
    /// **The conflict was latent, then it went live, and now it is gone.**
    /// `NoSpoilersCardDensity.widget` was unreachable until the widget's empty
    /// states moved onto `NoSpoilersMessageCard` — at which point one 3-case axis
    /// had to answer for all three widget families at once, and could not: it
    /// cost the small family its explanatory line, because `.widget` had no way
    /// to say which widget. `Theme.Card` and `Theme.MessageCard` below are that
    /// enum folded in here, and the density axis no longer exists.
    ///
    /// **Named `Canvas`, not `Surface`,** because `Theme.Palette.surface` is
    /// already a colour. One word meaning both "a place UI is drawn" and "the
    /// background behind it" inside one namespace is a trip hazard, and the
    /// colour spelling is the one worth keeping — it is what CSS and the wider
    /// design-system vocabulary use.
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

        /// The second line of a session row, under `rowLabel`.
        ///
        /// **`widgetLarge` has no second line, so asking for one traps.** The
        /// large family draws the session's full name on the label line and
        /// stops; there is no call site to transcribe, and inventing a value
        /// here would put a font on a role the design does not have. A row on
        /// that canvas passes no detail, so this is unreachable by construction
        /// — and if a detail is ever added there, the size is a design decision
        /// somebody has to make rather than one this file should guess.
        ///
        /// The four canvases that do have one disagree about what it *says* —
        /// an absolute date on iOS and macOS, a secondary session name in the
        /// medium widget, a relative time in the small one. That is the caller's
        /// business; only the size is decided here.
        public static func rowDetail(_ canvas: Canvas) -> Font {
            switch canvas {
            case .iosApp:       return .caption
            case .macPopover:   return .system(size: 11)
            case .widgetSmall:  return .caption2
            case .widgetMedium: return .caption2
            case .widgetLarge:
                preconditionFailure(
                    "the large widget's session row has no second line — pass no detail on .widgetLarge"
                )
            }
        }

        /// Where the weekend is, on the line under its name.
        ///
        /// **The two compact widget families trap**, because their header is one
        /// line — flag, name, round pill — with no room for a location and no
        /// call site to transcribe. `NoSpoilersWeekendMeta` is drawn only on the
        /// three canvases that have the room.
        public static func weekendLocation(_ canvas: Canvas) -> Font {
            switch canvas {
            case .iosApp:      return .subheadline
            case .macPopover:  return .caption
            case .widgetLarge: return .caption2
            case .widgetSmall, .widgetMedium:
                preconditionFailure(
                    "the compact widget header has no location line — do not draw NoSpoilersWeekendMeta on \(canvas)"
                )
            }
        }

        /// When the weekend runs, trailing the same line.
        ///
        /// A step quieter than `weekendLocation` on every canvas that has both,
        /// which is the ladder that makes the location read as the heading and
        /// the dates as the footnote.
        public static func weekendDateRange(_ canvas: Canvas) -> Font {
            switch canvas {
            case .iosApp:      return .caption
            case .macPopover:  return .caption2
            case .widgetLarge: return .caption2
            case .widgetSmall, .widgetMedium:
                preconditionFailure(
                    "the compact widget header has no date range — do not draw NoSpoilersWeekendMeta on \(canvas)"
                )
            }
        }

        /// The small uppercase eyebrow over a subordinate block — "Next up".
        ///
        /// **The one role with no canvas axis, because all four implementations
        /// already agreed**: `.caption2.weight(.semibold)`, uppercased, on iOS,
        /// macOS and both widget branches that draw it. Nothing to reconcile, so
        /// naming it is the whole change.
        public static let eyebrow: Font = .caption2.weight(.semibold)

        /// The name of the *next* weekend, under the eyebrow.
        ///
        /// **A step quieter than `rowLabel` on every canvas**, which is the
        /// ladder that keeps the weekend being shown louder than the one after
        /// it. `widgetSmall` traps: the small family draws one hero session and
        /// has no room for a footer at all.
        public static func nextUpName(_ canvas: Canvas) -> Font {
            switch canvas {
            case .iosApp:       return .subheadline.weight(.semibold)
            case .macPopover:   return .caption
            case .widgetMedium: return .caption2.weight(.medium)
            case .widgetLarge:  return .caption.weight(.semibold)
            case .widgetSmall:
                preconditionFailure(
                    "the small widget has no next-up footer — do not draw NoSpoilersNextUpFooter on \(canvas)"
                )
            }
        }

        /// When the next weekend starts.
        ///
        /// **This is the role, not the slot.** Three canvases draw it under
        /// `nextUpName`; the medium widget draws the same text trailing on the
        /// same line, because it only has one. The font is the same question
        /// either way, so `widgetMedium` returns a value rather than trapping —
        /// its footer passes no `detail` but still needs this to set the
        /// countdown it puts in the trailing slot.
        public static func nextUpDetail(_ canvas: Canvas) -> Font {
            switch canvas {
            case .iosApp:       return .caption
            case .macPopover:   return .caption2
            case .widgetMedium: return .caption2
            case .widgetLarge:  return .caption2
            case .widgetSmall:
                preconditionFailure(
                    "the small widget has no next-up footer — do not draw NoSpoilersNextUpFooter on \(canvas)"
                )
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
    /// **The card radii are not here.** `Theme.Card` resolves 24/18/14 per
    /// canvas, alongside the padding, fill and shadow that go with each of them.
    /// Restating those numbers here would make two answers to one question,
    /// which is the problem this file exists to remove — a card's radius is not
    /// independently choosable from its padding, so it lives with it.
    public enum Radius {
        /// The session accent bar — a 3pt-wide vertical rule. Four sites across
        /// three targets, all agreeing.
        public static let hairline: CGFloat = 2
        /// The macOS menu row hover highlight.
        public static let small: CGFloat = 6
        /// The session row, on every canvas that draws one.
        ///
        /// **This was 8pt on macOS and in the widget and 10pt on iOS**, which
        /// nobody decided — it is the same surface, drawn 2pt rounder in one
        /// target. Converging the four session rows onto `NoSpoilersSessionRow`
        /// forced a choice, and 8 won on the majority: two of the three targets
        /// already drew it, so one surface moves rather than two. The iOS row's
        /// corners are 2pt sharper as a result. The 10pt value had no other
        /// site and is gone.
        public static let medium: CGFloat = 8
    }

    /// The panel almost everything else sits inside: rounded, inset, filled
    /// white over the gradient, with a soft shadow under it.
    ///
    /// **This is `NoSpoilersCardDensity` folded in, and the fold is the whole
    /// point.** That enum was regular/compact/widget — the same idea as `Canvas`
    /// written a second way, in a second vocabulary, resolved by a second
    /// parameter. Every component that needed to vary by surface therefore took
    /// *either* a density or a `compact: Bool` or a canvas, and no call site
    /// could tell you which without reading it. One axis, one spelling.
    ///
    /// **Nothing here changes what is on screen.** regular's numbers are
    /// `iosApp`, compact's are `macPopover`, and widget's are all three widget
    /// families — which is exactly what `.widget` already resolved to, since
    /// `NoSpoilersCard` had no way to distinguish them either. The gain is not
    /// in this type; it is in `MessageCard` below, where the three families do
    /// differ and the old axis could not say so.
    ///
    /// **The seven values are one decision, not seven.** A card's radius is not
    /// independently choosable from its padding or its shadow — pick a size and
    /// they move together — so they resolve in one switch rather than in seven
    /// that could drift apart.
    public enum Card {
        public struct Geometry {
            public let cornerRadius: CGFloat
            public let horizontalPadding: CGFloat
            public let verticalPadding: CGFloat
            /// Shadow blur. **Not on the `Space` grid**, deliberately: this is a
            /// softness, not a gap, and it does not move when the rhythm does.
            public let shadowRadius: CGFloat
            public let shadowYOffset: CGFloat
            /// How opaque the white fill is over the gradient behind it.
            public let fillOpacity: Double
            /// **The widget's shadow is lighter than the apps'** — 0.06 against
            /// 0.08. A widget sits on the Home Screen wallpaper rather than on
            /// this product's own gradient, so its card has less to lift off.
            public let shadowOpacity: Double
        }

        public static func geometry(_ canvas: Canvas) -> Geometry {
            switch canvas {
            case .iosApp:
                return Geometry(
                    cornerRadius: 24,
                    horizontalPadding: Space.xxxl,
                    verticalPadding: Space.xxxl,
                    shadowRadius: 20,
                    shadowYOffset: Space.xl,
                    fillOpacity: 0.82,
                    shadowOpacity: 0.08
                )
            case .macPopover:
                return Geometry(
                    cornerRadius: 18,
                    horizontalPadding: Space.xxl,
                    verticalPadding: 14,
                    shadowRadius: 14,
                    shadowYOffset: Space.md,
                    fillOpacity: 0.78,
                    shadowOpacity: 0.08
                )
            case .widgetSmall, .widgetMedium, .widgetLarge:
                return Geometry(
                    cornerRadius: 14,
                    horizontalPadding: Space.xl,
                    verticalPadding: Space.lg,
                    shadowRadius: 10,
                    shadowYOffset: Space.sm,
                    fillOpacity: 0.74,
                    shadowOpacity: 0.06
                )
            }
        }
    }

    /// An empty or error state drawn inside a card: a symbol, a title, and a
    /// line explaining it.
    ///
    /// **This family exists because `NoSpoilersCardDensity` could not express
    /// it.** Its three values were resolved from `density == .widget`, which
    /// answered for all three widget families at once — and the small family is
    /// not like the other two. Measured against a hand-seeded off-season cache,
    /// `systemSmall` fits the symbol, the title and two lines of `.caption`; the
    /// third line truncated mid-word. With only a density to go on, the caller
    /// had to make that decision itself and pass `nil`, which is how a layout
    /// question ended up in the widget's view code as an optional.
    public enum MessageCard {
        /// Between the symbol, the title and the body.
        public static func contentSpacing(_ canvas: Canvas) -> CGFloat {
            switch canvas {
            case .iosApp, .macPopover:                        return Space.xl
            case .widgetSmall, .widgetMedium, .widgetLarge:   return Space.md
            }
        }

        /// The symbol above the title. **Not on the `Space` grid** — a glyph
        /// size, like `NextUp.flagHeight`.
        public static func iconSize(_ canvas: Canvas) -> CGFloat {
            switch canvas {
            case .iosApp, .macPopover:                        return 34
            case .widgetSmall, .widgetMedium, .widgetLarge:   return 28
            }
        }

        public static func bodyFont(_ canvas: Canvas) -> Font {
            switch canvas {
            case .iosApp, .macPopover:                        return .subheadline
            case .widgetSmall, .widgetMedium, .widgetLarge:   return .caption
            }
        }

        /// Whether the explanatory line under the title is drawn at all.
        ///
        /// **`widgetSmall` is the one canvas that says no**, and it says so
        /// here rather than at the call site: the caller knows what the state
        /// means, and this file knows how much room the canvas has. The title
        /// carries the state on its own at that size.
        public static func showsBody(_ canvas: Canvas) -> Bool {
            switch canvas {
            case .widgetSmall:                                       return false
            case .iosApp, .macPopover, .widgetMedium, .widgetLarge:  return true
            }
        }
    }

    /// The pill or label trailing a session row, saying what state it is in.
    ///
    /// **This is the last of the three axes, and it was the worst of them.**
    /// `NoSpoilersStatusBadge` took a `compact: Bool` — not a surface, not a
    /// size, a boolean — which every call site had to answer for itself. Ten
    /// sites across three targets did, and one of them got it wrong: the macOS
    /// popover passed `compact: true` for its live and upcoming badges and
    /// nothing at all for its finished one, so a single `stateLabel` function
    /// drew two badge sizes in the same row depending on the state.
    ///
    /// **That outlier is settled here as `.caption2`,** with the two sites
    /// against the one. The popover's finished badge is 1pt smaller than it
    /// was; nothing else on any surface moves.
    ///
    /// **`widgetSmall` traps.** The small family has no badge — it says the
    /// session's state on the row's second line instead, which is why
    /// `NoSpoilersSessionRow` has an `EmptyView` trailing overload for it.
    public enum Badge {
        /// The base size. Weight is the *style*'s business, not the canvas's —
        /// live is bold where finished and upcoming are medium, on every
        /// surface.
        public static func font(_ canvas: Canvas) -> Font {
            switch canvas {
            case .iosApp:       return .caption
            case .macPopover:   return .caption2
            case .widgetMedium: return .caption2
            case .widgetLarge:  return .caption
            case .widgetSmall:  preconditionFailure(badgeless)
            }
        }

        /// **Only the two pill styles read this.** A finished badge is bare
        /// text with no capsule behind it, so it has nothing to inset.
        public static func horizontalPadding(_ canvas: Canvas) -> CGFloat {
            switch canvas {
            case .iosApp:       return Space.lg
            case .macPopover:   return Space.md
            case .widgetMedium: return Space.md
            case .widgetLarge:  return Space.lg
            case .widgetSmall:  preconditionFailure(badgeless)
            }
        }

        public static func verticalPadding(_ canvas: Canvas) -> CGFloat {
            switch canvas {
            case .iosApp:       return Space.sm
            case .macPopover:   return Space.xs
            case .widgetMedium: return Space.xs
            case .widgetLarge:  return Space.sm
            case .widgetSmall:  preconditionFailure(badgeless)
            }
        }

        private static let badgeless =
            "the small widget has no status badge — it puts the state on the row's second line"
    }

    /// The geometry of a session row — the one component every canvas draws,
    /// and the one that existed four times over.
    ///
    /// These numbers are transcribed from those four implementations, which
    /// agreed on the shape (a 3pt accent rule, a label stack, a trailing badge
    /// on a lifted panel) and on almost nothing else. Where they disagreed for a
    /// reason the reason is recorded below; where they disagreed for no reason
    /// they were collapsed, and the collapse is recorded too.
    ///
    /// **`labelSpacing` and `labelLineLimit` are not session-row-only.** Both
    /// describe the label-over-detail stack that the next-up footer draws too,
    /// so `NoSpoilersNextUpFooter` reads them from here rather than growing a
    /// near-identical pair beside them. The rest of this family is the accent
    /// rule and the panel, which only the session row has.
    public enum Row {
        /// The accent rule down the leading edge. All four implementations drew
        /// it 3pt wide at `Radius.hairline`; only its height varied.
        public static let accentWidth: CGFloat = 3

        /// **The rule is as tall as the label stack it sits beside**, which is
        /// why this is not one number: the stack is two lines of `.body` on iOS
        /// and one line of `.caption` in the medium widget.
        ///
        /// `widgetSmall` is taller than `widgetMedium` despite the smaller
        /// family, because the small widget draws a single hero row where the
        /// medium draws two of them.
        public static func accentHeight(_ canvas: Canvas) -> CGFloat {
            switch canvas {
            case .iosApp:       return 32
            case .macPopover:   return 28
            case .widgetSmall:  return 28
            case .widgetMedium: return 24
            case .widgetLarge:  return 26
            }
        }

        /// Between the accent rule, the label stack, and the trailing badge.
        public static func contentSpacing(_ canvas: Canvas) -> CGFloat {
            switch canvas {
            case .iosApp:       return Space.lg
            case .macPopover:   return Space.md
            case .widgetSmall:  return Space.md
            case .widgetMedium: return Space.md
            case .widgetLarge:  return Space.md
            }
        }

        /// Between the label and the detail line under it.
        ///
        /// **`widgetLarge` was 3pt** — one of the eleven literals `Space` records
        /// as off the 2pt grid. It rounds to `xxs` here rather than surviving as
        /// a stray, which is a 1pt change on the one canvas that can actually be
        /// screenshotted.
        public static func labelSpacing(_ canvas: Canvas) -> CGFloat {
            switch canvas {
            case .iosApp:       return Space.xs
            case .macPopover:   return Space.xxs
            case .widgetSmall:  return Space.xxs
            case .widgetMedium: return Space.xxs
            case .widgetLarge:  return Space.xxs
            }
        }

        /// **`nil` means unlimited, which is what the app surfaces want.** A
        /// widget cannot reflow, so its rows truncate; the iOS card and the
        /// macOS popover grow instead.
        public static func labelLineLimit(_ canvas: Canvas) -> Int? {
            switch canvas {
            case .iosApp:       return nil
            case .macPopover:   return nil
            case .widgetSmall:  return 1
            case .widgetMedium: return 1
            case .widgetLarge:  return 1
            }
        }

        /// A floor under the label column's width.
        ///
        /// **Only the popover has one**, at 100pt. It is the narrowest canvas
        /// with a trailing badge — 300pt total — so it is the only one where a
        /// short session name would let the badge drift left of where it sits in
        /// the row above. `nil` elsewhere means the column is as wide as its
        /// content.
        public static func labelMinWidth(_ canvas: Canvas) -> CGFloat? {
            switch canvas {
            case .iosApp:       return nil
            case .macPopover:   return 100
            case .widgetSmall:  return nil
            case .widgetMedium: return nil
            case .widgetLarge:  return nil
            }
        }

        /// The panel a row sits on: `Palette.surfaceRaised`, inset and rounded.
        public struct Surface {
            public let horizontalPadding: CGFloat
            public let verticalPadding: CGFloat
            public let cornerRadius: CGFloat
        }

        /// **`widgetSmall` returns `nil`, and that is a design answer rather
        /// than a missing one.** The small family draws exactly one session row
        /// directly on the widget's own background — no padding, no fill, no
        /// corners — because a card inside a card at that size reads as a
        /// mistake. Every other canvas draws several rows and needs each one
        /// bounded.
        public static func surface(_ canvas: Canvas) -> Surface? {
            switch canvas {
            case .iosApp:
                return Surface(
                    horizontalPadding: Space.lg,
                    verticalPadding: Space.md,
                    cornerRadius: Radius.medium
                )
            case .macPopover:
                return Surface(
                    horizontalPadding: Space.lg,
                    verticalPadding: Space.sm,
                    cornerRadius: Radius.medium
                )
            case .widgetSmall:
                return nil
            case .widgetMedium, .widgetLarge:
                return Surface(
                    horizontalPadding: Space.md,
                    verticalPadding: Space.xs,
                    cornerRadius: Radius.medium
                )
            }
        }
    }

    /// The "Next up" footer — the block naming the weekend *after* the one a
    /// surface is showing.
    ///
    /// **Four of the five implementations were one design at four sizes**:
    /// a flag, the weekend's name over an optional detail line, a spacer, and
    /// one trailing element. What varied was which trailing element (a round
    /// pill on iOS, macOS and the large widget; the countdown itself on the
    /// medium widget, which has no room for a second line) and whether the
    /// eyebrow is drawn at all.
    ///
    /// The fifth — the extra-large widget's right-hand column — is not in this
    /// family and did not converge. It is a 140pt-wide vertical stack with the
    /// flag on its own line and the round pill inline beside the location: a
    /// sidebar rather than a footer, and a genuinely different design.
    public enum NextUp {
        /// **The flag scales with the canvas, not with the session row's
        /// accent rule.** 17pt on macOS is the one value off the 2pt grid, and
        /// it stays: this is an image height, not a gap, so the spacing rhythm
        /// does not apply to it.
        public static func flagHeight(_ canvas: Canvas) -> CGFloat {
            switch canvas {
            case .iosApp:       return 20
            case .macPopover:   return 17
            case .widgetMedium: return 12
            case .widgetLarge:  return 18
            case .widgetSmall:
                preconditionFailure(
                    "the small widget has no next-up footer — do not draw NoSpoilersNextUpFooter on \(canvas)"
                )
            }
        }

        /// Between the flag, the name stack, and the trailing element.
        public static func contentSpacing(_ canvas: Canvas) -> CGFloat {
            switch canvas {
            case .iosApp:       return Space.lg
            case .macPopover:   return Space.md
            case .widgetMedium: return Space.sm
            case .widgetLarge:  return Space.md
            case .widgetSmall:
                preconditionFailure(
                    "the small widget has no next-up footer — do not draw NoSpoilersNextUpFooter on \(canvas)"
                )
            }
        }

        /// Whether the "Next up" eyebrow is drawn above the row.
        ///
        /// **`widgetMedium` is the only surface that omits it**, because its
        /// footer is a single dense line under a divider and the divider
        /// already says "something else starts here". Every other canvas has
        /// the vertical room and draws it.
        public static func showsLabel(_ canvas: Canvas) -> Bool {
            switch canvas {
            case .iosApp:       return true
            case .macPopover:   return true
            case .widgetMedium: return false
            case .widgetLarge:  return true
            case .widgetSmall:
                preconditionFailure(
                    "the small widget has no next-up footer — do not draw NoSpoilersNextUpFooter on \(canvas)"
                )
            }
        }

        /// Between the eyebrow and the row under it. Unreachable wherever
        /// `showsLabel` is false, which is why it traps there rather than
        /// returning a gap nothing uses.
        public static func labelGap(_ canvas: Canvas) -> CGFloat {
            switch canvas {
            case .iosApp:      return Space.md
            case .macPopover:  return Space.sm
            case .widgetLarge: return Space.xxs
            case .widgetSmall, .widgetMedium:
                preconditionFailure(
                    "no next-up eyebrow is drawn on \(canvas) — check Theme.NextUp.showsLabel first"
                )
            }
        }
    }

    /// The small uppercase label introducing a group of rows.
    ///
    /// **The two implementations differed only in padding** — 12/4 on the
    /// shared About screen against 10/2 on the macOS settings screen — and
    /// that difference could not have been platform intent, because `AboutView`
    /// is shared: on macOS both screens sit in the *same* popover, one under
    /// the other. 12/4 won on call sites, two against one.
    public enum SectionLabel {
        public static let horizontalPadding = Space.xxl
        public static let topPadding = Space.xl
        public static let bottomPadding = Space.xs
    }

    /// A labelled row with one control or link trailing.
    public enum DetailRow {
        public static let horizontalPadding = Space.xxl

        /// **Both implementations used 9pt**, which is two of the eleven
        /// literals `Space` records as off the 2pt grid — and, as it turns out,
        /// both of them. 9 is equidistant between `md` and `lg`; `md` wins
        /// because it is what every other row's vertical padding already uses.
        /// A 1pt tightening at two sites.
        public static let verticalPadding = Space.md
    }

    /// The banner at the top of a full-screen surface — the app's icon, its
    /// name, and one line under it, on a blush field.
    ///
    /// **The one component that needed no canvas axis.** The shared About
    /// screen and the macOS settings screen drew this identically, down to
    /// every number; only the line under the name differed, and that is
    /// content rather than geometry.
    public enum ScreenHeader {
        public static let iconSize: CGFloat = 56
        public static let spacing = Space.md
        public static let verticalPadding = Space.xxxl
    }

    /// The weekend header — the block naming which Grand Prix a surface is
    /// showing.
    ///
    /// **This is deliberately not a `Row`-sized family, because the header did
    /// not converge the way the session row did.** Its four arrangements are
    /// genuinely different designs rather than one design at four sizes: iOS
    /// puts the wordmark and flag on one line and centres the name beneath,
    /// macOS puts all three on a single line, the compact widget families draw
    /// flag-name-pill in one row, and the large family stacks the name over its
    /// metadata. Only the metadata line itself repeated, and that is what
    /// `NoSpoilersWeekendMeta` and the tokens here cover.
    public enum Header {
        /// The country's flag, beside the weekend's name.
        ///
        /// **The one measurement every canvas has**, which is what makes it a
        /// token rather than five literals: five headers, five heights, one
        /// ladder from the iOS card down to the medium widget. It is an image
        /// height rather than a gap, so `Space` does not apply — same as
        /// `NextUp.flagHeight`, which is a different and smaller ladder for the
        /// footer.
        ///
        /// **Two flags are not on this ladder.** The extra-large widget's
        /// sidebar draws one at 24pt, and it is not a header; the macOS menu
        /// bar draws one at 14pt, and it is not on any canvas — it is an
        /// `NSHostingView` sharing one line with the app icon.
        public static func flagHeight(_ canvas: Canvas) -> CGFloat {
            switch canvas {
            case .iosApp:       return 28
            case .macPopover:   return 20
            case .widgetSmall:  return 16
            case .widgetMedium: return 14
            case .widgetLarge:  return 20
            }
        }

        /// Between the flag and what sits beside it on the header's first line.
        public static func contentSpacing(_ canvas: Canvas) -> CGFloat {
            switch canvas {
            case .iosApp:       return Space.xl
            case .macPopover:   return Space.lg
            case .widgetSmall:  return Space.sm
            case .widgetMedium: return Space.sm
            case .widgetLarge:  return Space.lg
            }
        }

        /// Between the round pill, the location and the date range.
        ///
        /// **iOS is a step wider than the other two** — 8pt against 6pt — which
        /// is the one difference here that reads as deliberate rather than
        /// accidental: it is the only canvas where this line is set in
        /// `.subheadline` rather than a caption size.
        public static func metaSpacing(_ canvas: Canvas) -> CGFloat {
            switch canvas {
            case .iosApp:      return Space.md
            case .macPopover:  return Space.sm
            case .widgetLarge: return Space.sm
            case .widgetSmall, .widgetMedium:
                preconditionFailure(
                    "the compact widget header has no metadata line — do not draw NoSpoilersWeekendMeta on \(canvas)"
                )
            }
        }
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
    /// **Asset names are here now**, and the bundle is settled with them. The
    /// three `"nospoilers-icon"` sites reached the same asset through two
    /// spellings — `.module` from inside this package, `noSpoilersCoreBundle`
    /// from the macOS target — which is why naming the string had to wait for
    /// the screen-header convergence rather than hide half the duplication.
    /// `noSpoilersCoreBundle` won: it is `.module` by definition, so it is the
    /// one spelling that is correct from both sides of the package boundary,
    /// and it is now the only one in the product.
    public enum Icon {
        /// The app's own icon, drawn at 56pt on the screen header and 16pt in
        /// the macOS menu bar. Always loaded from `noSpoilersCoreBundle`.
        public static let appIcon = "nospoilers-icon"

        /// The flag asset for a country, by ISO code. Lowercased here so no
        /// call site has to remember that the asset names are.
        ///
        /// The country code arrives from the feed in whatever case it was
        /// written; the assets are all lowercase.
        public static func flag(for countryCode: String) -> String {
            "flag-\(countryCode.lowercased())"
        }

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
