import Foundation
import SwiftUI

// MARK: - Strings
// User-facing text produced by NoSpoilersCore (e.g. menu bar label strings, shared About screen).
// Centralised here for future localisation.
// Swap format functions to String(localized:) with interpolation when a Localizable.strings file is added.

public enum Strings {
    public enum AppInfo {
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
        public static let done: LocalizedStringKey               = "Done"
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

        /// Elapsed or remaining time, e.g. `2h` / `45m`. Were in iOS and macOS.
        public static func durationHours(_ hours: Int) -> String { "\(hours)h" }
        public static func durationMinutes(_ minutes: Int) -> String { "\(minutes)m" }

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
