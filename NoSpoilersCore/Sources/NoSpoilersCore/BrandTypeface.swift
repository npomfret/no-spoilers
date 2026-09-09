import CoreText
import SwiftUI

/// The one typeface this product ships, and the only place it is registered.
///
/// **Why bundle a face at all.** The Formula One logo image was deleted on 2026-08-13 and replaced
/// with `Text(Strings.AppInfo.name)` in the system font — the right emergency move, and it worked:
/// 4.1(a) has not been cited since. But it left the app's name set in the same face as every OS
/// alert and Settings row on the device, which is to say it left the app with no identity. Six
/// open-licensed faces were measured as the actual wordmark string on 2026-08-26 and Chivo won;
/// `docs/guides/brand.md` records the comparison and why the other five lost.
///
/// **Chivo, and not something with motorsport in it.** This is the exact surface that was rejected
/// three times under 4.1(a) Copycats, so the rule the search ran under was *distinctive without
/// being sport-referential* — no obliques, no clipped terminals, no speed-line display faces, and
/// nothing already worn by this sport's team branding. An italic was asked for and turned down for
/// the same reason: the mark that came off this surface was red, italic and speed-derived.
///
/// **SIL OFL 1.1**, which permits bundling in a paid app and asks for no in-app attribution.
/// `Chivo-OFL.txt` ships beside the font in this bundle because the licence requires the font to
/// travel with its licence text. The copyright line carries **no Reserved Font Name**, so the usual
/// constraint on subsetting or renaming does not apply here.
public enum BrandTypeface {

    /// The PostScript name of the weight the wordmark is set in, and yes, it really is spelled
    /// like that.
    ///
    /// **`Chivo.ttf` is a variable font whose `wght` axis defaults to 500**, and Google Fonts
    /// publishes no static instances for this family — the upstream directory holds only the two
    /// variable files. CoreText exposes each named instance as its own face, with names built from
    /// the family's own odd `Chivo-Medium` base: `Chivo-Medium_ExtraBold` is the 800 instance.
    ///
    /// So asking for `"Chivo"` is not a near miss, it is the wrong weight — measured on
    /// 2026-08-26, "NO SPOILERS" at 15pt with 1.4 tracking comes out 111.4pt under `"Chivo"` and
    /// 113.1pt under this name, the latter matching a `CTFontDescriptor` carrying
    /// `kCTFontVariationAttribute` `wght` 800 exactly. Using the descriptor was the fallback plan;
    /// it turned out not to be needed, which is what keeps this file free of a `UIFont`/`NSFont`
    /// conditional.
    private static let wordmarkFace = "Chivo-Medium_ExtraBold"

    /// The family every instance of the above reports, used to prove registration worked.
    private static let wordmarkFamily = "Chivo"

    private static let resourceName = "Chivo"

    /// The wordmark's face, registering it into this process the first time anyone asks.
    ///
    /// **Lazy, and owned here, because the widget is a separate process.** A `static let` is
    /// initialised once per process under the runtime's own lock, so each host that draws a
    /// wordmark registers exactly once and no host has to remember to. The alternative — a call in
    /// each of the three targets' entry points — is three chances to spell it differently and one
    /// chance to forget entirely in the extension, which would fail as a silent fallback rather
    /// than as the reported one below.
    ///
    /// **`fixedSize:` rather than `size:`.** `Font.custom(_:size:)` scales with Dynamic Type;
    /// `.system(size:)`, which this replaces, does not. Keeping it fixed keeps `.medium`'s
    /// measurement against the 300pt popover row meaningful — letting the wordmark grow with the
    /// accessibility sizes is a real change with a real question behind it (what that row does at
    /// AX5) and it is not this change.
    public static func wordmark(size: CGFloat) -> Font {
        guard registration == nil else {
            // The system's own heaviest weight, which is what the wordmark was set in before
            // Chivo and what `docs/guides/brand.md` measured Chivo against. Fixed size for the
            // reason above: `.system(size:)` does not scale with Dynamic Type, so the fallback
            // keeps the measurements in `NoSpoilersWordmarkSize` meaning what they say.
            return .system(size: size, weight: .heavy)
        }
        return .custom(wordmarkFace, fixedSize: size)
    }

    /// Why the wordmark's face is unavailable, or `nil` on every ordinary run.
    ///
    /// Public so a test can assert the shipped bundle registers cleanly without reaching into the
    /// private storage to do it.
    public static var registrationFailure: String? { registration }

    /// **Fails loudly, because the alternative is invisible.** A face that is missing, misnamed or
    /// left out of the resource bundle does not break a build and does not log: `Font.custom`
    /// silently substitutes the system font, every `xcodebuild` still succeeds, and the app ships
    /// looking exactly as it did before this file existed. That is the one failure this whole
    /// change has to be protected from, so registration proves the face is reachable by name
    /// afterwards rather than trusting that the register call returning `true` was enough.
    ///
    /// **What "loudly" means depends on who is listening, and that changed on 2026-09-09.** All
    /// three checks below used to `preconditionFailure`, and `NoSpoilersWordmark` is the first view
    /// in `ContentView.body` — so on a device where any of them failed, the app trapped before it
    /// drew a pixel and the user got a Home Screen and no explanation. That is not loud, it is
    /// mute: an App Store user cannot read a trap. The third check is the one that makes this
    /// device-specific rather than build-specific — `CTFontManagerRegisterFontsForURL` refuses a
    /// face already registered on the device, which a font-installer app or a configuration
    /// profile can do system-wide without this app knowing.
    ///
    /// So the trap survives where it works — `#if DEBUG`, which still stops a developer dead on
    /// the first launch after breaking the bundle — and a release build reports the identical
    /// sentence to `LaunchDiagnostics`, which puts it on screen. The fallback is never silent,
    /// which was the whole objection to having one.
    private static let registration: String? = {
        guard let url = noSpoilersCoreBundle.url(forResource: resourceName, withExtension: "ttf") else {
            return refuse(
                "\(resourceName).ttf is not in noSpoilersCoreBundle. It lives in "
                + "NoSpoilersCore/Sources/NoSpoilersCore/Resources/ and reaches every host through "
                + "the package's .process(\"Resources\") rule."
            )
        }

        var error: Unmanaged<CFError>?
        guard CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) else {
            return refuse(
                "could not register \(url.lastPathComponent): "
                + String(describing: error?.takeRetainedValue())
            )
        }

        // CTFontCreateWithName substitutes rather than failing, so this asks it for the face and
        // checks what came back — the only way to tell a registered font from a fallback.
        let resolved = CTFontCopyFamilyName(CTFontCreateWithName(wordmarkFace as CFString, 12, nil)) as String
        guard resolved == wordmarkFamily else {
            return refuse(
                "registered \(url.lastPathComponent) but \"\(wordmarkFace)\" resolves to "
                + "\"\(resolved)\" rather than \"\(wordmarkFamily)\". The wordmark would render in "
                + "the system font and nothing else would say so."
            )
        }

        return nil
    }()

    /// Traps in development, reports in release. See `registration`.
    private static func refuse(_ reason: String) -> String {
        #if DEBUG
        preconditionFailure(reason)
        #else
        LaunchDiagnostics.shared.record(LaunchProblem(
            id: "brand-typeface",
            summary: Strings.Diagnostics.typefaceSummary,
            detail: reason
        ))
        return reason
        #endif
    }
}
