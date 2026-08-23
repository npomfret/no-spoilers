import Foundation
import SwiftUI

// MARK: - Strings
// User-facing text produced by NoSpoilersCore (e.g. menu bar label strings, shared About screen).
// Centralised here for future localisation.
// Swap format functions to String(localized:) with interpolation when a Localizable.strings file is added.

public enum Strings {
    /// Labels on controls that do the same thing wherever they appear.
    public enum Actions {
        /// Dismisses a sheet. Used by the shared About screen and by macOS
        /// Settings, which had its own copy.
        public static let done: LocalizedStringKey = "Done"
    }

    public enum AppInfo {
        /// The product name, and the only place it is written down.
        ///
        /// It was written out four times — here, the iOS app's `App.name` (dead,
        /// deleted), the macOS `Settings.appName`, and the widget's
        /// `Widget.displayName`. The widget's copy is the one that mattered: it
        /// is what the Home Screen gallery shows, so a rename that missed it
        /// would have left the old name in the place users pick the widget from.
        public static let name: LocalizedStringKey = "No Spoilers"

        /// The version line under the app name, e.g. `v1.0.22 (13)`.
        /// The build number is included because the marketing version alone
        /// cannot identify a build: every TestFlight build of a release shares
        /// it, so `v1.0.22` was the same string on builds 3 through 13.
        public static func version(_ marketing: String, build: String) -> String {
            "v\(marketing) (\(build))"
        }
    }

    public enum About {
        public static let acknowledgements: LocalizedStringKey   = "Acknowledgements"
        public static let scheduleData: LocalizedStringKey       = "Schedule data"
        public static let sessionData: LocalizedStringKey        = "Session data"
        public static let flagIcons: LocalizedStringKey          = "Flag icons"
        public static let trademarks: LocalizedStringKey         = "Trademarks"
        public static let trademarkDisclaimer: LocalizedStringKey = "Formula 1, F1, and related marks are trademarks of Formula One Licensing BV. This app is not affiliated with, endorsed by, or sponsored by Formula One Licensing BV, Liberty Media, or the FIA."
    }

    /// The vocabulary for rendering a schedule, shared by every target that
    /// draws one.
    ///
    /// Each of these was written out identically in two or three of the targets'
    /// own `Strings.swift` files. `swift-patterns.md` already had the rule that
    /// decides it — *"shared strings that cross target boundaries belong in
    /// `NoSpoilersCore`"* — they had simply never moved, so a translator would
    /// have been handed "In Progress" three times.
    public enum Schedule {
        /// The round badge, e.g. `R7`. Was in all three targets.
        public static func roundLabel(_ round: Int) -> String { "R\(round)" }

        /// A session happening now. Was in all three targets.
        public static let inProgress: LocalizedStringKey = "In Progress"

        /// Heading over the next weekend. Was in all three targets.
        public static let comingUp: LocalizedStringKey = "Next up"

        /// One unit of elapsed or remaining time, e.g. `2h` / `45m`.
        ///
        /// `durationHours` and `durationMinutes` came from iOS and macOS, which
        /// had a copy each; days and seconds are new here because
        /// `CountdownFormatter` needs the same four suffixes the countdown
        /// ladders were spelling out inline. It is one vocabulary either way —
        /// "finished 2h ago" and "in 2h 15m" are the same `2h`.
        public static func durationDays(_ days: Int) -> String { "\(days)d" }
        public static func durationHours(_ hours: Int) -> String { "\(hours)h" }
        public static func durationMinutes(_ minutes: Int) -> String { "\(minutes)m" }
        public static func durationSeconds(_ seconds: Int) -> String { "\(seconds)s" }

        /// The schedule could not be loaded. Was in iOS and the widget.
        ///
        /// **Only the title is shared.** Each target's body tells the reader
        /// something different and correct about how to fix it — iOS says to
        /// pull to refresh, the widget says to open the app — so the bodies stay
        /// where they are.
        public static let unavailableTitle: LocalizedStringKey = "Schedule unavailable"

        /// Formats a session start in the user's locale and time zone, e.g.
        /// "Fri, 12 Jun, 20:00" (en_GB) or "Fri, Jun 12, 8:00 PM" (en_US).
        /// Defaults to `Locale.current` / `TimeZone.current` so a session stored as a
        /// UTC instant renders in the device's local wall-clock time.
        public static func sessionDateTime(
            _ date: Date,
            locale: Locale = .current,
            timeZone: TimeZone = .current
        ) -> String {
            var style = Date.FormatStyle()
                .weekday(.abbreviated)
                .day()
                .month(.abbreviated)
                .hour()
                .minute()
            style.locale = locale
            style.timeZone = timeZone
            return date.formatted(style)
        }

        /// The span a weekend covers, e.g. `6 Jun → 8 Jun`, collapsing to a
        /// single date when both ends land on the same day.
        ///
        /// This was written out three times — iOS, macOS (inline in the header,
        /// not even extracted) and the widget — each building the same
        /// `.day().month(.abbreviated)` style, formatting both ends, and
        /// collapsing when equal. A formatting rule is a design token; that one
        /// was a copy-paste.
        ///
        /// **The separator was not the same in all three.** iOS said "to" while
        /// macOS and the widget said "→", so unifying them is a visible change
        /// on iOS rather than a pure move. The arrow wins on the majority and
        /// because it stays legible at `.caption2` in a widget, where the word
        /// competes with the dates either side of it.
        public static func dateRange(
            from start: Date,
            to end: Date,
            locale: Locale = .current,
            timeZone: TimeZone = .current
        ) -> String {
            var style = Date.FormatStyle().day().month(.abbreviated)
            style.locale = locale
            style.timeZone = timeZone
            let startText = start.formatted(style)
            let endText = end.formatted(style)
            return startText == endText ? startText : "\(startText) → \(endText)"
        }
    }

    public enum MenuBar {
        public static let live: String                                                          = "now"
        public static func liveWithSession(_ session: String) -> String                        { "\(session) — now" }
        public static func countdownDays(_ days: Int) -> String                                { "in \(days)d" }
        public static func countdownHoursMinutes(_ hours: Int, _ minutes: Int) -> String       { "\(hours)h \(minutes)m" }
        public static func countdownMinutes(_ minutes: Int) -> String                          { "\(minutes)m" }
        public static func sessionWithCountdown(_ session: String, _ time: String) -> String   { "\(session) · \(time)" }
    }

    public enum SessionNames {
        public enum Display {
            public static let fp1              = "Free Practice 1"
            public static let fp2              = "Free Practice 2"
            public static let fp3              = "Free Practice 3"
            public static let qualifying       = "Qualifying"
            public static let sprintQualifying = "Sprint Qualifying"
            public static let sprint           = "Sprint"
            public static let race             = "Race"
        }
        /// The three alert groups. Named for what a reader would call them, not for the
        /// `SessionKind` cases underneath — "Races" covers the Sprint, and "Qualifying" covers
        /// Sprint Qualifying, which is why each row also prints `SessionAlertGroup.summary`.
        public enum Group {
            public static let practice   = "Free practice"
            public static let qualifying = "Qualifying"
            public static let races      = "Races"
        }
        public enum Short {
            public static let fp1              = "FP1"
            public static let fp2              = "FP2"
            public static let fp3              = "FP3"
            public static let qualifying       = "Quali"
            public static let sprintQualifying = "Sprint Quali"
            public static let sprint           = "Sprint"
            public static let race             = "Race"
        }
    }

    /// What the alerts say, on both platforms.
    ///
    /// **In Core since 2026-08-23**, with the scheduler that builds the notification content from
    /// it. Copy that ships to two apps and is written in one of them is copy that diverges, and
    /// this is the one string in the product a user cannot choose not to read — the spoiler
    /// surface `.claude/rules/spoiler-safety.md` calls out by name.
    ///
    /// `scripts/alerts_check.py` extracts the two bodies from this block rather than transcribing
    /// them, so that a sample notification cannot drift from the product and still screenshot
    /// convincingly. If this moves again, that extractor moves with it.
    public enum Alerts {
        public static func startingSoonTitle(_ grandPrix: String) -> String { grandPrix }
        public static func startingSoonBody(session: String, minutes: Int) -> String {
            minutes == 1
                ? "\(session) starts in 1 minute"
                : "\(session) starts in \(minutes) minutes"
        }

        public static func safeToWatchTitle(_ grandPrix: String) -> String { grandPrix }
        public static func safeToWatchBody(session: String) -> String {
            "\(session) has finished — safe to watch"
        }

        // MARK: Settings

        public static let sectionLabel: LocalizedStringKey    = "Alerts"
        public static let rowTitle: LocalizedStringKey        = "Session alerts"
        public static let screenSubtitle: LocalizedStringKey  = "Session alerts"
        public static let intro: LocalizedStringKey           = "Be told when a session is about to start, and when it has finished and is safe to watch. Neither ever mentions a result."
        public static let remindBeforeStart: LocalizedStringKey = "Before a session starts"
        public static let announceSafeToWatch: LocalizedStringKey = "When a session is safe to watch"
        public static let leadTime: LocalizedStringKey        = "How much warning"
        public static func leadMinutes(_ minutes: Int) -> String {
            minutes == 1 ? "1 minute" : "\(minutes) minutes"
        }
        public static let whichSessions: LocalizedStringKey   = "Which sessions"

        /// Shown when the system has been told no. Neither app can reopen that prompt itself.
        ///
        /// Named per platform because the sentence has to tell someone where to go, and "Settings"
        /// and "System Settings" are different places. `AboutView` already branches this way for
        /// the same reason.
        public static let deniedTitle: LocalizedStringKey     = "Notifications are turned off"
        #if os(macOS)
        public static let deniedBody: LocalizedStringKey      = "macOS is holding these back. Turn them on for No Spoilers in System Settings and they will start arriving."
        public static let openSettings: LocalizedStringKey    = "Open System Settings"
        #else
        public static let deniedBody: LocalizedStringKey      = "iOS is holding these back. Turn them on for No Spoilers in Settings and they will start arriving."
        public static let openSettings: LocalizedStringKey    = "Open Settings"
        #endif
    }

    public enum RaceNames {
        public static func grandPrix(_ name: String) -> String { "\(name) Grand Prix" }
    }

    public enum CountryNames {
        private static let map: [String: String] = [
            "Australian":          "Australia",
            "Chinese":             "China",
            "Japanese":            "Japan",
            "Miami":               "United States",
            "Canadian":            "Canada",
            "Monaco":              "Monaco",
            "Barcelona-Catalunya": "Spain",
            "Austrian":            "Austria",
            "British":             "United Kingdom",
            "Belgian":             "Belgium",
            "Hungarian":           "Hungary",
            "Dutch":               "Netherlands",
            "Italian":             "Italy",
            "Spanish":             "Spain",
            "Azerbaijan":          "Azerbaijan",
            "Singapore":           "Singapore",
            "United States":       "United States",
            "Mexican":             "Mexico",
            "Brazilian":           "Brazil",
            "Las Vegas":           "United States",
            "Qatar":               "Qatar",
            "Abu Dhabi":           "United Arab Emirates",
        ]
        public static func name(for feedName: String) -> String {
            map[feedName] ?? feedName
        }
    }
}
