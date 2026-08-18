import SwiftUI

// MARK: - BrandPalette
// Single source of truth for all brand colours across macOS app, iOS app, and widget.
// Hex values are the canonical spec from docs/guides/brand.md.

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
}
