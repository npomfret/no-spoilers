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
/// `BrandPalette` remains the colour source of truth and is not folded in here;
/// naming colour roles that point at it comes later, and rewriting every colour
/// call site is a sweep rather than an addition.
public enum Theme {
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
}
