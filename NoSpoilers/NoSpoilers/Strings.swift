import AppIntents
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
    /// What Siri says, and what Spotlight and the Shortcuts app call it.
    ///
    /// **Spoken text, which is the strictest surface in the product.** A notification can at least
    /// be read privately; this can be asked for out loud in a room. It says the session, the
    /// weekend and a clock time, and stops — the same three fields every other surface leads with,
    /// and for the same reason.
    ///
    /// **Only half of this intent's copy is here**, and the split is the framework's rather than a
    /// choice. Anything the system reads at install time — the intent's title and description, the
    /// shortcut's short title, and the spoken phrases — is extracted at build time by
    /// `appintentsmetadataprocessor`, which fails the build on anything that is not a literal at
    /// the declaration site. Those four are inline in `NextSessionIntent.swift`, under a comment
    /// saying so. What is left here is what the intent says at run time, which is not extracted
    /// and follows the ordinary rule.
    enum Intents {
        static func inProgress(session: String, grandPrix: String) -> String {
            "\(session) is in progress at the \(grandPrix)."
        }

        static func startsAt(session: String, grandPrix: String, when: String) -> String {
            "\(session) at the \(grandPrix) starts on \(when)."
        }

        /// The off-season and a phone that has never fetched a schedule, answered the same way.
        /// Claiming the season is over when the truth is a failed fetch would be worse than
        /// vague.
        static let nothingScheduled =
            "There is no session scheduled yet. Open No Spoilers to refresh the calendar."
    }
    enum Error {
        static let unavailableBody: LocalizedStringKey    = "Pull to refresh or open the app again to update the shared widget cache."
    }
}
