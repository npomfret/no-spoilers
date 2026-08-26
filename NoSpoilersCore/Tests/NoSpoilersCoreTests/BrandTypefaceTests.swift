import CoreText
import XCTest
@testable import NoSpoilersCore

/// A bundled typeface has exactly one failure mode and no symptoms.
///
/// If `Chivo.ttf` is dropped from the resource bundle, misnamed, or asked for under a name CoreText
/// does not hold, `Font.custom` substitutes the system font, every `xcodebuild` still succeeds, and
/// the app ships looking precisely as it did before the face was added. Nothing logs. The only way
/// to notice is to look at the pixels, and the whole reason `BrandTypeface` has a `precondition` in
/// it is that nobody reliably does.
///
/// So these tests do the looking. They run in the package's own test host, where `.module` is the
/// same bundle every app target gets, which makes "is the font in the bundle" answerable long
/// before it is a screenshot.
final class BrandTypefaceTests: XCTestCase {

    /// Asking for the wordmark must register the face into this process.
    ///
    /// `CTFontCreateWithName` substitutes rather than failing, so the assertion is on what came
    /// back, not on whether the call returned something.
    func testAskingForTheWordmarkRegistersTheFace() {
        _ = BrandTypeface.wordmark(size: 15)
        XCTAssertEqual(family(of: "Chivo-Medium_ExtraBold"), "Chivo")
    }

    /// The trap this face actually carries.
    ///
    /// `Chivo.ttf` is a variable font whose `wght` axis defaults to 500 and Google Fonts publishes
    /// no statics, so `"Chivo"` on its own is not a near miss — it is Medium where the wordmark
    /// wants ExtraBold. The difference is 1.7pt across eleven characters at 15pt, which is
    /// invisible in a screenshot and would quietly make every measurement in
    /// `NoSpoilersWordmarkSize` wrong.
    func testTheWordmarkNameIsHeavierThanTheFamilyDefault() {
        _ = BrandTypeface.wordmark(size: 15)

        let extraBold = width("NO SPOILERS", face: "Chivo-Medium_ExtraBold", size: 15, tracking: 1.4)
        let familyDefault = width("NO SPOILERS", face: "Chivo", size: 15, tracking: 1.4)

        XCTAssertGreaterThan(extraBold, familyDefault)
    }

    /// The measurement `NoSpoilersWordmarkSize.fontSize` is documented against.
    ///
    /// 65.2pt at 9pt is what decided that `.medium` could stay at 9pt when the face changed — the
    /// macOS popover row is 300pt wide and shares it with the centred Grand Prix name. If a future
    /// font bump moves this, the comment in `SharedChrome` becomes a lie about a row that will
    /// start wrapping, so it is pinned here rather than trusted to be re-read.
    func testTheMediumWordmarkStillFitsTheMeasurementThePopoverRowWasSizedAgainst() {
        _ = BrandTypeface.wordmark(size: 9)

        let measured = width("NO SPOILERS", face: "Chivo-Medium_ExtraBold", size: 9, tracking: 0.6)

        XCTAssertEqual(measured, 65.2, accuracy: 0.5)
    }

    /// The licence has to travel with the font. The OFL requires it and a resource bundle is where
    /// this one actually ships, so its absence is a licensing fault rather than a cosmetic one.
    func testTheLicenceShipsBesideTheFont() {
        XCTAssertNotNil(noSpoilersCoreBundle.url(forResource: "Chivo", withExtension: "ttf"))
        XCTAssertNotNil(noSpoilersCoreBundle.url(forResource: "Chivo-OFL", withExtension: "txt"))
    }

    private func family(of face: String) -> String {
        CTFontCopyFamilyName(CTFontCreateWithName(face as CFString, 12, nil)) as String
    }

    private func width(_ text: String, face: String, size: CGFloat, tracking: CGFloat) -> CGFloat {
        let font = CTFontCreateWithName(face as CFString, size, nil)
        let attributed = NSAttributedString(string: text, attributes: [
            .font: font,
            .kern: tracking,
        ])
        return attributed.size().width
    }
}
