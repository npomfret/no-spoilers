import Foundation

/// Whether this launch is the first one on a new build of the app.
///
/// Exists for the widget. WidgetKit keeps the last timeline an extension handed it and shows
/// those archived entries until the timeline expires or something asks for a reload — and the
/// app's only reload request is `ScheduleStore.refresh()`, which asks when the *schedule* has
/// changed and says nothing when the *code* has. So a build that changes what the widget draws
/// leaves the old picture on the Home Screen for up to the timeline horizon (48 hours) after the
/// update installs. On 2026-09-03 that was build 10013 still drawing the next-weekend footer that
/// `09a0a20` had removed.
///
/// This is the decision only; the caller does the reloading. The decision is the part that can be
/// wrong in two directions — reload on every launch and the budget is spent on nothing, never
/// reload and the stale picture stays — and the part that can be tested without WidgetKit.
public enum InstalledBuild {
    /// Where the last-seen build is recorded. Each app's own `UserDefaults.standard`, as with
    /// `SessionAlertDefaults`: the record answers "has *this process* run this build before",
    /// which is not a thing to share through the App Group.
    public static let recordedBuildKey = "installedBuild.recorded"

    /// Records `build` and reports whether it differs from the one recorded last time.
    ///
    /// No record at all reads as changed. That is the first launch after install, when there is
    /// nothing placed to reload, so the answer costs nothing — and it keeps "never recorded" from
    /// being a third state the caller has to reason about.
    public static func changed(to build: String, in defaults: UserDefaults = .standard) -> Bool {
        let recorded = defaults.string(forKey: recordedBuildKey)
        defaults.set(build, forKey: recordedBuildKey)
        return recorded != build
    }
}
