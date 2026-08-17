import SwiftUI

// MARK: - BrandPalette
// Single source of truth for all brand colours across macOS app, iOS app, and widget.
// Hex values are the canonical spec from docs/brand.md.

public enum BrandPalette {
    // Primary
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

    // Warm neutrals for text on ivory surfaces (supplementary — not in brand.md)
    public static let secondaryText = Color(red: 0.43, green: 0.40, blue: 0.39)
    public static let tertiaryText  = Color(red: 0.57, green: 0.53, blue: 0.51)
}
