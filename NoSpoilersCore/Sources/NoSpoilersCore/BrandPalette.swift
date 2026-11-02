import SwiftUI

// MARK: - BrandPalette
// Single source of truth for all brand colours across macOS app, iOS app, and widget.
// Hex values are the canonical spec from docs/guides/brand.md.
//
// **One hex per name, in either appearance.** Nothing here knows about dark mode: a name is
// a colour, not a role, and a colour does not change when the room goes dark. The pairing —
// "ivory in light, charcoal in dark" — is `Theme.Palette`'s job, which is why the dark
// entries below have their own names rather than hiding behind the light ones.

public enum BrandPalette {
    // Primary
    /// **This one value exists in four places, and three of them are JSON.**
    /// It is also the system tint, which has to be an `AccentColor.colorset` in
    /// each target's asset catalog — Apple gives no way to point that at Swift —
    /// so `NoSpoilers/`, `NoSpoilersMac/` and `NoSpoilersWidget/` each carry the
    /// same three components. Change this and change those; nothing will fail
    /// to compile if you forget, the app will just tint itself with the old red.
    public static let signalRed   = Color(red: 0.9373, green: 0.1686, blue: 0.1765) // #EF2B2D
    public static let deepMaroon  = Color(red: 0.4784, green: 0.0471, blue: 0.0588) // #7A0C0F

    // Surfaces
    public static let ivory       = Color(red: 1.0000, green: 0.9686, blue: 0.9490) // #FFF7F2
    public static let blush       = Color(red: 0.9647, green: 0.8431, blue: 0.8314) // #F6D7D4

    // Text / structure
    public static let smoke       = Color(red: 0.1216, green: 0.1020, blue: 0.1020) // #1F1A1A
    public static let mistGrey    = Color(red: 0.8510, green: 0.8235, blue: 0.8118) // #D9D2CF

    // Semantic
    public static let successGreen  = Color(red: 0.1804, green: 0.6078, blue: 0.3882) // #2E9B63
    public static let upcomingBlue  = Color(red: 0.2392, green: 0.4980, blue: 0.8000) // #3D7FCC

    // Warm neutrals for text on ivory surfaces (supplementary — see the text roles in docs/guides/brand.md)
    //
    // **These two values came from the web binding on 2026-08-18**, which had held a
    // darker pair under different names. They were the same two roles with two answers,
    // and contrast on ivory decided it rather than seniority: secondary went 5.32:1 →
    // 6.66:1, tertiary 3.31:1 → 4.05:1. Nothing in this file gets lighter.
    public static let secondaryText = Color(red: 0.3725, green: 0.3412, blue: 0.3294) // #5F5754
    public static let tertiaryText  = Color(red: 0.5098, green: 0.4706, blue: 0.4627) // #827876

    // The lift. Not a ground — `docs/guides/brand.md` prefers ivory for those — but the
    // colour a row or card is tinted with to sit above one, and the bright end of the
    // background gradient. It was `Color.white` at three call sites until it was named.
    public static let white       = Color(red: 1.0000, green: 1.0000, blue: 1.0000) // #FFFFFF

    // Dark appearance. Chosen on 2026-09-05 against the same WCAG sRGB formula the light
    // set was measured with; the figures are in docs/guides/brand.md and pinned by
    // `ThemePaletteContrastTests`. Warm like the light set: every one of these carries a
    // little red, the way ivory and mist grey do, so the two appearances read as one product.
    /// The dark ground. The dark answer to ivory.
    public static let charcoal    = Color(red: 0.0902, green: 0.0745, blue: 0.0745) // #171313
    /// A dark maroon wash for tinted headers, gradients and pills. The dark answer to blush.
    public static let oxblood     = Color(red: 0.1843, green: 0.0824, blue: 0.0863) // #2F1516
    /// The dark lift: what a row or card is tinted with above charcoal. The dark answer to white.
    public static let graphite    = Color(red: 0.1725, green: 0.1490, blue: 0.1490) // #2C2626
    /// Borders and dividers on charcoal. The dark answer to mist grey.
    public static let cinder      = Color(red: 0.2314, green: 0.2000, blue: 0.2000) // #3B3333
    /// Supporting copy on charcoal, 8.51:1. Primary text on charcoal is `ivory`.
    public static let secondaryTextDark = Color(red: 0.7255, green: 0.6824, blue: 0.6667) // #B9AEAA
    /// Quiet copy on charcoal, 5.06:1 — clears the 4.5:1 its light counterpart misses.
    public static let tertiaryTextDark  = Color(red: 0.5569, green: 0.5176, blue: 0.5020) // #8E8480

    // December's approved night scene. Decorative bulb colours are independent of session state.
    public static let decemberSkyTop = Color(red: 0.1373, green: 0.2039, blue: 0.3020) // #23344D
    public static let decemberSky = Color(red: 0.0353, green: 0.0706, blue: 0.1216) // #09121F
    public static let decemberPanel = Color(red: 0.0824, green: 0.1255, blue: 0.1922) // #152031
    public static let decemberText = Color(red: 0.6941, green: 0.7333, blue: 0.7922) // #B1BBCA
    public static let decemberWordmark = Color(red: 1, green: 0.2706, blue: 0.2941) // #FF454B
    public static let decemberWarm = Color(red: 1, green: 0.8392, blue: 0.5294) // #FFD687
    public static let decemberRed = Color(red: 1, green: 0.3137, blue: 0.2667) // #FF5044
    public static let decemberGreen = Color(red: 0.2745, green: 0.9098, blue: 0.5569) // #46E88E
    public static let decemberBlue = Color(red: 0.3255, green: 0.6392, blue: 1) // #53A3FF
    public static let decemberAmber = Color(red: 1, green: 0.6941, blue: 0.2588) // #FFB142
    public static let decemberSnowShadow = Color(red: 0.6627, green: 0.7490, blue: 0.8510) // #A9BFD9
    public static let decemberSnow = Color(red: 0.9333, green: 0.9647, blue: 1) // #EEF6FF
    public static let decemberSnowBase = Color(red: 0.7176, green: 0.8000, blue: 0.8980) // #B7CCE5
}
