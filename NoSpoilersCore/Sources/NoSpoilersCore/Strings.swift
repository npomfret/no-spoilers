import Foundation
import SwiftUI

// MARK: - Strings
// User-facing text produced by NoSpoilersCore (e.g. menu bar label strings, shared About screen).
// Centralised here for future localisation.
// Swap format functions to String(localized:) with interpolation when a Localizable.strings file is added.

public enum Strings {
    public enum AppInfo {
        public static let name: LocalizedStringKey = "No Spoilers"
    }

    public enum About {
        public static let acknowledgements: LocalizedStringKey   = "Acknowledgements"
        public static let scheduleData: LocalizedStringKey       = "Schedule data"
        public static let sessionData: LocalizedStringKey        = "Session data"
        public static let flagIcons: LocalizedStringKey          = "Flag icons"
        public static let branding: LocalizedStringKey           = "F1 logo"
        public static let trademarks: LocalizedStringKey         = "Trademarks"
        public static let trademarkDisclaimer: LocalizedStringKey = "Formula 1, F1, and related marks are trademarks of Formula One Licensing BV. This app is not affiliated with, endorsed by, or sponsored by Formula One Licensing BV, Liberty Media, or the FIA."
        public static let done: LocalizedStringKey               = "Done"
    }

    public enum Schedule {
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
