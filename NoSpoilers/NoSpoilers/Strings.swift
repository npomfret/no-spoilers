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
        static let installFooter: LocalizedStringKey = "Today View and Lock Screen are different places — make sure you are on the Home Screen. There is a Lock Screen widget too, added a different way; see What No Spoilers can do."
        /// Puts the prompt card away for good. The steps stay in About.
        static let dismissPrompt: LocalizedStringKey = "Not now"
        static let aboutSectionLabel: LocalizedStringKey = "Widget"
    }
    /// The help sheet: one section per thing this app can do that is not the screen you are on.
    ///
    /// **Written because five of the six were undiscoverable.** A Lock Screen widget has to be
    /// added through Lock Screen customisation, a Live Activity appears only when a session is
    /// close, and a Siri phrase has to be guessed. None of them announce themselves, and the app
    /// had instructions for the Home Screen widget alone — which is the one thing it already
    /// nagged people about on the main screen.
    ///
    /// Every string here describes the schedule, a surface, or a gesture. No session outcome can
    /// be expressed in any of them, which is the property to keep when adding one.
    enum Help {
        static let sectionLabel: LocalizedStringKey  = "Help"
        static let rowTitle: LocalizedStringKey      = "What No Spoilers can do"
        static let screenSubtitle: LocalizedStringKey = "What No Spoilers can do"
        static let intro: LocalizedStringKey = "Six places the weekend can reach you, and never a result in any of them."

        static let homeScreenTitle: LocalizedStringKey = "On your Home Screen"

        static let lockScreenTitle: LocalizedStringKey = "On your Lock Screen"
        static let lockScreenBody: LocalizedStringKey = "A tile with the Grand Prix, the session and its countdown, or a single line beside the clock. Both also turn up in StandBy."
        /// Numbered on screen by position, so the numbers are never in the translated text.
        static let lockScreenSteps: [LocalizedStringKey] = [
            "Touch and hold your Lock Screen, then tap Customise",
            "Tap the Lock Screen picture, then the area under the clock",
            "Search for No Spoilers and pick a shape"
        ]
        static let lockScreenFooter: LocalizedStringKey = "The single line goes in the narrow slot above the clock, beside the date."

        static let countdownTitle: LocalizedStringKey = "The countdown, once a session is close"
        static let countdownBody: LocalizedStringKey = "When a session is within a few hours, open No Spoilers and the countdown moves to your Lock Screen on its own — and to the Dynamic Island, if your iPhone has one. It clears itself when the session starts. The first time, iOS will ask whether to allow it."

        static let alertsTitle: LocalizedStringKey = "Alerts"
        static let alertsBody: LocalizedStringKey = "Be told before a session starts, and again when one has finished and is safe to watch. Choose which sessions and how much warning under Session alerts, above."

        static let siriTitle: LocalizedStringKey = "Ask out loud"
        static let siriBody: LocalizedStringKey = "Siri answers without opening the app, and without a signal. It is in Spotlight and Shortcuts too."
        static let siriPhrase: LocalizedStringKey = "\u{201C}When is the next session in No Spoilers?\u{201D}"

        static let iPadTitle: LocalizedStringKey = "On iPad"
        static let iPadBody: LocalizedStringKey = "There is an extra large widget on iPad only: the whole weekend in one column and what is coming next in the other."
    }

    /// The Lock Screen countdown, and the refusal that can switch it off.
    ///
    /// **Written the day the prompt was discovered.** iOS asks *"Allow Live Activities from
    /// No Spoilers?"* on the first activity, and a Don't Allow left the feature inert with nothing
    /// anywhere in the app admitting it. These are what admits it. Target-private rather than in
    /// Core because ActivityKit is iOS-only and the Mac app has no such surface to describe.
    enum Activity {
        static let sectionLabel: LocalizedStringKey = "Lock Screen"
        static let intro: LocalizedStringKey = "When a session is close, open No Spoilers and the countdown moves to your Lock Screen until the session starts."
        static let deniedTitle: LocalizedStringKey = "Live Activities are turned off"
        static let deniedBody: LocalizedStringKey = "iOS is holding these back, so the countdown cannot reach your Lock Screen. Turn Live Activities on for No Spoilers in Settings."
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
