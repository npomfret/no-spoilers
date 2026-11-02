import Foundation

/// The running bundle's version numbers, read from `Info.plist`.
///
/// Both keys are always present in a built bundle, so a missing one is a build
/// configuration fault and not a runtime condition — this crashes rather than
/// substituting a placeholder. The About screen must report the version of the
/// running bundle rather than conceal a missing build setting.
public enum AppVersion {
    /// `CFBundleShortVersionString` — the marketing version, e.g. `1.0.22`.
    public static var marketing: String { value(for: "CFBundleShortVersionString") }

    /// `CFBundleVersion` — the build number, and the only thing that tells two
    /// builds of the same marketing version apart. `submit_build.py` reserves it
    /// against App Store Connect and the build tags before archiving. Builds 1 to 125 came
    /// from Xcode Cloud, which wrote its run number here until that path was
    /// removed; see `docs/guides/building.md` for why the two bands are apart.
    public static var build: String { value(for: "CFBundleVersion") }

    private static func value(for key: String) -> String {
        guard let value = Bundle.main.infoDictionary?[key] as? String else {
            fatalError("\(key) is missing from Info.plist — the bundle is misbuilt")
        }
        return value
    }
}
