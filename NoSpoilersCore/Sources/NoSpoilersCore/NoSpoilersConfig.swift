import Foundation

public enum NoSpoilersConfig {
    public static let appGroupID = "group.pomocorp.no-spoilers"

    /// The widget's `StaticConfiguration` kind.
    ///
    /// Shared because two targets need the same literal: the widget declares it, and the app asks
    /// `WidgetCenter` whether a widget of this kind is installed. Written out twice it would be a
    /// silent failure — the app would decide nobody has the widget and nag every user forever.
    ///
    /// The value is load-bearing on device. Changing it makes every installed widget a different
    /// widget, so it must not be renamed to match a Swift type.
    public static let widgetKind = "NoSpoilersWidget"

    /// Where the schedule is fetched from: the f1calendar feed, or whatever the process
    /// environment names instead.
    ///
    /// **This is the seam the screenshot tooling declined on 2026-08-18** and the Live Activity
    /// work needed on 2026-09-06. Every capture of the app itself races the fetch: the app
    /// restores its cache, then fetches, and a fetch that succeeds replaces both the cache and the
    /// screen. Seeding a fixture therefore only ever worked with the network off, and a Live
    /// Activity — which the app requests only for a session within eight hours — could not be
    /// seen at all on a day with nothing on. The alternative that was declined then was a flag
    /// meaning "do not refresh"; this is not that. The app still fetches, from wherever it is
    /// told, and a fixture is a feed served from a directory — `docs/guides/testing.md` has the
    /// three commands.
    ///
    /// **The override is an `http(s)` URL or the process traps.** `URLResponse.requireSuccess`
    /// refuses anything that is not an HTTP response, so a `file:` root would fail at every fetch
    /// with `notHTTP` and read as an outage; better to refuse it here, once, by name. Unset, this
    /// is the production feed and nothing here has read the environment at all.
    ///
    /// The widget extension does not inherit the app's environment and reads the App Group cache
    /// the app writes, so pointing the app at a fixture is enough to put it on every surface.
    public static let feedRoot: URL = {
        guard let override = ProcessInfo.processInfo.environment[feedRootVariable] else {
            return productionFeedRoot
        }
        guard let url = URL(string: override), let scheme = url.scheme,
              scheme == "http" || scheme == "https" else {
            preconditionFailure("\(feedRootVariable) is \(override), which is not an http(s) URL")
        }
        return url
    }()

    /// The environment variable that redirects the feed. On the simulator it is passed through
    /// `simctl launch` as `SIMCTL_CHILD_NO_SPOILERS_FEED_ROOT`.
    public static let feedRootVariable = "NO_SPOILERS_FEED_ROOT"

    /// True when the feed has been redirected. Logged by the fetcher so a capture of fake data can
    /// never be mistaken for the calendar.
    public static var feedRootIsOverridden: Bool { feedRoot != productionFeedRoot }

    private static let productionFeedRoot =
        URL(string: "https://raw.githubusercontent.com/sportstimes/f1/main/_db/f1/")!
}
