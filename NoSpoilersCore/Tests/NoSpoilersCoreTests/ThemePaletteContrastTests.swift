import SwiftUI
import XCTest
@testable import NoSpoilersCore

/// The contrast figures `docs/guides/brand.md` quotes, measured rather than trusted.
///
/// The guide's numbers are the reason session names stay on `textPrimary` in every state and the
/// reason the dark set is the dark set. A palette edit that moves one of them does not fail a
/// build; it fails an App Review, which is how the macOS popover was rejected under Guideline 4
/// in April 2026. So the ratios are pinned here to two decimal places, the same way
/// `BrandTypefaceTests` pins the 9pt wordmark measurement: if a value changes, the guide has to
/// change in the same commit or this fails.
///
/// **This also proves the mechanism.** Every role resolves through a platform dynamic colour,
/// and the dark column can only come out right if `Color.resolve(in:)` actually gets the dark
/// value when the environment says dark. A dark ratio equal to its light one would mean the
/// appearance is being ignored somewhere, which is exactly the failure the pins used to hide.
final class ThemePaletteContrastTests: XCTestCase {

    func testTextRolesOnTheGroundInLight() {
        XCTAssertEqual(ratio(Theme.Palette.textPrimary, on: Theme.Palette.surface, .light), 16.25, accuracy: 0.02)
        XCTAssertEqual(ratio(Theme.Palette.textSecondary, on: Theme.Palette.surface, .light), 6.66, accuracy: 0.02)
        XCTAssertEqual(ratio(Theme.Palette.textTertiary, on: Theme.Palette.surface, .light), 4.05, accuracy: 0.02)
    }

    func testTextRolesOnTheGroundInDark() {
        XCTAssertEqual(ratio(Theme.Palette.textPrimary, on: Theme.Palette.surface, .dark), 17.42, accuracy: 0.02)
        XCTAssertEqual(ratio(Theme.Palette.textSecondary, on: Theme.Palette.surface, .dark), 8.51, accuracy: 0.02)
        XCTAssertEqual(ratio(Theme.Palette.textTertiary, on: Theme.Palette.surface, .dark), 5.06, accuracy: 0.02)
    }

    /// The state colours do not change with the appearance, so the whole question is whether
    /// the same three hexes still clear the 3:1 component bar on charcoal. They do, with room.
    func testStateColoursOnTheGroundInBothAppearances() {
        XCTAssertEqual(ratio(Theme.Palette.stateFinished, on: Theme.Palette.surface, .light), 3.31, accuracy: 0.02)
        XCTAssertEqual(ratio(Theme.Palette.stateLive, on: Theme.Palette.surface, .light), 3.93, accuracy: 0.02)
        XCTAssertEqual(ratio(Theme.Palette.stateUpcoming, on: Theme.Palette.surface, .light), 3.89, accuracy: 0.02)

        XCTAssertEqual(ratio(Theme.Palette.stateFinished, on: Theme.Palette.surface, .dark), 5.25, accuracy: 0.02)
        XCTAssertEqual(ratio(Theme.Palette.stateLive, on: Theme.Palette.surface, .dark), 4.44, accuracy: 0.02)
        XCTAssertEqual(ratio(Theme.Palette.stateUpcoming, on: Theme.Palette.surface, .dark), 4.48, accuracy: 0.02)
    }

    /// The one figure the guide has always led with: `successGreen` on the lifted row surface.
    /// The row is `surfaceLift` at 65% over `surface`, so this is the composited colour.
    func testFinishedGreenOnALiftedRow() {
        XCTAssertEqual(ratio(Theme.Palette.stateFinished, on: liftedRow(.light), .light), 3.43, accuracy: 0.02)
        XCTAssertEqual(ratio(Theme.Palette.stateFinished, on: liftedRow(.dark), .dark), 4.62, accuracy: 0.02)
    }

    // MARK: - WCAG, in linear sRGB

    private func luminance(_ color: Color, _ scheme: ColorScheme) -> Double {
        let resolved = resolve(color, scheme)
        return 0.2126 * Double(resolved.linearRed)
            + 0.7152 * Double(resolved.linearGreen)
            + 0.0722 * Double(resolved.linearBlue)
    }

    private func ratio(_ foreground: Color, on background: Color, _ scheme: ColorScheme) -> Double {
        let a = luminance(foreground, scheme)
        let b = luminance(background, scheme)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    private func resolve(_ color: Color, _ scheme: ColorScheme) -> Color.Resolved {
        var environment = EnvironmentValues()
        environment.colorScheme = scheme
        return color.resolve(in: environment)
    }

    /// `surfaceRaised` composited over `surface`, as an opaque colour.
    private func liftedRow(_ scheme: ColorScheme) -> Color {
        let lift = resolve(Theme.Palette.surfaceLift, scheme)
        let ground = resolve(Theme.Palette.surface, scheme)
        let alpha: Float = 0.65
        return Color(
            .sRGB,
            red: Double(lift.red * alpha + ground.red * (1 - alpha)),
            green: Double(lift.green * alpha + ground.green * (1 - alpha)),
            blue: Double(lift.blue * alpha + ground.blue * (1 - alpha))
        )
    }
}
