import SwiftUI

// MARK: - Strings
// All user-facing text in the iOS app, centralised here for future localisation.
// Text and Button views accept LocalizedStringKey directly, so Text(Strings.Foo.bar)
// will automatically pick up translations once a Localizable.strings file is added.
//
// Dynamic strings (countdowns, "Round N", "Next session in Xd Yh") are centralised as format
// functions below. Swap to String(localized:) with interpolation when a Localizable.strings file is added.

enum Strings {
    enum Sessions {
        static let header: LocalizedStringKey             = "Sessions"
        static func weekendCompleteStatus() -> String     { "Weekend complete" }
        static let countdownNow: String                   = "now"
        /// Wraps the units CountdownFormatter renders, e.g. "in 3d 4h". The
        /// phrasing is here rather than in the formatter because it is the part
        /// a translator has to reorder.
        static func countdownIn(_ units: String) -> String { "in \(units)" }
        static func finishedAgo(_ time: String) -> String    { "Finished \(time)" }
        static func sessionFinished(name: String, ago: String) -> String    { "\(name) finished \(ago) ago" }
        static func sessionInProgress(_ name: String) -> String             { "\(name) is in progress" }
        static func sessionUpcoming(name: String, countdown: String) -> String { "\(name) \(countdown)" }
    }
    enum Navigation {
        static let currentWeekend: LocalizedStringKey     = "Current"
        static let jumpToCurrentWeekend: LocalizedStringKey = "Jump to the current race weekend"
    }
    enum Widget {
        static let installTitle: LocalizedStringKey  = "Put it on your Home Screen"
        static let installBody: LocalizedStringKey   = "The widget shows the next session without opening anything. It is where No Spoilers is meant to live."
        /// Numbered on screen by position, so the numbers are never in the translated text.
        static let installSteps: [LocalizedStringKey] = [
            "Touch and hold an empty part of your Home Screen",
            "Tap the + button in the top corner",
            "Search for No Spoilers, pick a size, and tap Add Widget"
        ]
        static let installFooter: LocalizedStringKey = "Today View and Lock Screen are different places — make sure you are on the Home Screen."
        /// Puts the prompt card away for good. The steps stay in About.
        static let dismissPrompt: LocalizedStringKey = "Not now"
        static let aboutSectionLabel: LocalizedStringKey = "Widget"
        static let aboutRowTitle: LocalizedStringKey = "How to add the widget"
    }
    /// Notification copy.
    ///
    /// **This is the only text in the product the user cannot choose not to read.** Everything
    /// else waits until someone opens the app or glances at a widget; this arrives on a lock
    /// screen, possibly in front of other people. So it says the session and the weekend and
    /// stops: no outcome, no adjective, nothing that reads as commentary. "Qualifying has
    /// finished" is a fact about a clock. Anything warmer starts to sound like it knows how it
    /// went.
    enum Alerts {
        static func startingSoonTitle(_ grandPrix: String) -> String { grandPrix }
        static func startingSoonBody(session: String, minutes: Int) -> String {
            minutes == 1
                ? "\(session) starts in 1 minute"
                : "\(session) starts in \(minutes) minutes"
        }

        static func safeToWatchTitle(_ grandPrix: String) -> String { grandPrix }
        static func safeToWatchBody(session: String) -> String {
            "\(session) has finished — safe to watch"
        }

        // MARK: Settings

        static let sectionLabel: LocalizedStringKey    = "Alerts"
        static let rowTitle: LocalizedStringKey        = "Session alerts"
        static let screenSubtitle: LocalizedStringKey  = "Session alerts"
        static let intro: LocalizedStringKey           = "Be told when a session is about to start, and when it has finished and is safe to watch. Neither ever mentions a result."
        static let remindBeforeStart: LocalizedStringKey = "Before a session starts"
        static let announceSafeToWatch: LocalizedStringKey = "When a session is safe to watch"
        static let leadTime: LocalizedStringKey        = "How much warning"
        static func leadMinutes(_ minutes: Int) -> String {
            minutes == 1 ? "1 minute" : "\(minutes) minutes"
        }
        static let whichSessions: LocalizedStringKey   = "Which sessions"
        /// Shown when iOS has been told no. The app cannot reopen that prompt itself.
        static let deniedTitle: LocalizedStringKey     = "Notifications are turned off"
        static let deniedBody: LocalizedStringKey      = "iOS is holding these back. Turn them on for No Spoilers in Settings and they will start arriving."
        static let openSettings: LocalizedStringKey    = "Open Settings"
    }

    enum Error {
        static let unavailableBody: LocalizedStringKey    = "Pull to refresh or open the app again to update the shared widget cache."
    }
}
