import Foundation

/// The running bundle's version numbers, read from `Info.plist`.
///
/// Both keys are always present in a built bundle, so a missing one is a build
/// configuration fault and not a runtime condition — this crashes rather than
/// substituting a placeholder. The two call sites this replaced each had their
/// own fallback, and they disagreed: the About screen showed `—`, while the
/// update check substituted `"0"`, which compares older than every published
/// release and would have shown a permanent "update available" banner instead
/// of reporting the real fault.
public enum AppVersion {
    /// `CFBundleShortVersionString` — the marketing version, e.g. `1.0.22`.
    public static var marketing: String { value(for: "CFBundleShortVersionString") }

    /// `CFBundleVersion` — the build number, and the only thing that tells two
    /// builds of the same marketing version apart. Xcode Cloud writes its run
    /// number here; `release.sh` writes 10000 and up. See task 14 Decision 1
    /// for why the two paths occupy deliberately separate bands.
    public static var build: String { value(for: "CFBundleVersion") }

    private static func value(for key: String) -> String {
        guard let value = Bundle.main.infoDictionary?[key] as? String else {
            fatalError("\(key) is missing from Info.plist — the bundle is misbuilt")
        }
        return value
    }
}
