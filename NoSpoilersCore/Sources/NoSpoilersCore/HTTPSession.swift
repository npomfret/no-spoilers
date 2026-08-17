import Foundation

/// The one `URLSession` every request in this app goes through.
///
/// There were three fetch sites and two policies: `ScheduleFetcher` configured its own session and
/// wrote down why, while `OpenF1Client` and `UpdateChecker` used `URLSession.shared` and inherited
/// whatever Apple ships — measured on macOS 26.5 as `timeoutIntervalForRequest 60`,
/// `timeoutIntervalForResource 604800` (seven days). Neither of them decided that; they just never
/// said anything, which is worse than either answer because it reads as intentional.
///
/// ## Ephemeral, not `.shared`
///
/// `ScheduleFetcher` runs inside the widget extension as well as the apps, and Apple advises
/// against `.shared` in extension contexts. Losing the URL cache costs nothing here: `ScheduleCache`
/// is the caching layer for the schedule, and neither of the other two callers wants a cached
/// answer — a stale "no release yet" or a stale "record not published yet" is precisely the wrong
/// reply. Ephemeral also drops the process-wide cookie storage, which none of these hosts uses.
///
/// ## The timeouts
///
/// `timeoutIntervalForRequest` is an **idle** timeout — the wait for the next piece of data, reset
/// each time some arrives — not a budget for the whole request. `timeoutIntervalForResource` is the
/// total. Eight seconds of silence is therefore a much weaker bound than it looks.
///
/// Eight comes from the widget: a widget stuck waiting on a hung request shows the redacted
/// placeholder — grey bars — for as long as it waits, so `ScheduleFetcher` has always bounded
/// itself there.
///
/// It is applied to the other two on evidence rather than by eye. Three requests to each of the
/// three hosts on 2026-08-17 came back in **0.05–0.50s** end to end, the slowest being OpenF1 at
/// 0.49s — sixteen times inside the bound. That is one moment on one network and says nothing about
/// the tail, which is why the number is loose rather than tight: it is set to catch a hang, not to
/// police latency.
///
/// The bound matters most to `SessionEndConfirmer.pollLoop`, which walks its pending sessions
/// sequentially and only then sleeps 120 seconds. Under `.shared` two hung lookups stretched that
/// cycle to four minutes — a confirmer that exists to retire an "In Progress" badge early, running
/// at half speed exactly when the network is bad. A lookup that times out costs one retry out of
/// the dozens the grace window allows; a cycle that silently doubles costs the feature.
///
/// ## If a site needs different numbers
///
/// Build a session there and say why. Overriding this is a decision; inheriting Apple's defaults
/// by omission is not.
///
/// ## The argument against converging, recorded
///
/// `URLSession.shared` pools connections across the process, and a separate session means a
/// separate pool. Here that is worth nothing: the three call sites talk to three different hosts
/// (`raw.githubusercontent.com`, `api.openf1.org`, `api.github.com`) and none of them could reuse
/// another's connection.
public enum HTTPSession {
    public static let shared: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 20
        return URLSession(configuration: configuration)
    }()
}
