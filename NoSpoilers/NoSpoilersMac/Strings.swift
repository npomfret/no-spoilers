import SwiftUI

// MARK: - Strings
// All user-facing text in the macOS app, centralised here for future localisation.
// Text and Button views accept LocalizedStringKey directly, so Text(Strings.Foo.bar)
// will automatically pick up translations once a Localizable.strings file is added.
//
// Dynamic strings (countdowns, "Finished Xh ago") are centralised as format functions below.
// Swap to String(localized:) with interpolation when a Localizable.strings file is added.

enum Strings {
    enum Popover {
        static let inProgress: LocalizedStringKey   = "In Progress"
        static let updateAvailable: LocalizedStringKey = "Update available"
        static let brewUpgradeCommand               = "brew update && brew upgrade --cask npomfret/tap/no-spoilers"
        static let copyCommand: LocalizedStringKey  = "Copy"
        static let copied: LocalizedStringKey       = "Copied!"
        static let offSeason: LocalizedStringKey    = "Off season"
        static let noSessions: LocalizedStringKey   = "No upcoming sessions found"
        static let website: LocalizedStringKey      = "Website"
        static let about: LocalizedStringKey        = "About"
        static let settings: LocalizedStringKey     = "Settings"
        static let quit: LocalizedStringKey         = "Quit"
        static let comingUp: LocalizedStringKey     = "Coming up..."
        static func roundLabel(_ round: Int) -> String    { "R\(round)" }
        static func durationHours(_ h: Int) -> String        { "\(h)h" }
        static func durationMinutes(_ m: Int) -> String      { "\(m)m" }
        static func finishedAgo(_ time: String) -> String    { "Finished \(time) ago" }
        static let countdownZero: String                  = "0s"
        static func countdownDaysHoursMinutes(_ d: Int, _ h: Int, _ m: Int) -> String      { "\(d)d \(h)h \(m)m" }
        static func countdownHoursMinutesSeconds(_ h: Int, _ m: Int, _ s: Int) -> String   { "\(h)h \(m)m \(s)s" }
        static func countdownMinutesSeconds(_ m: Int, _ s: Int) -> String                  { "\(m)m \(s)s" }
        static func countdownSeconds(_ s: Int) -> String  { "\(s)s" }
        static func dateRange(start: String, end: String) -> String { "\(start) → \(end)" }
        static func countdownWithBullet(_ time: String) -> String   { "· \(time)" }
    }
    enum Settings {
        static let appName: LocalizedStringKey      = "No Spoilers"
        static let tagline: LocalizedStringKey      = "F1 schedule · spoiler free"
        static let launchAtLogin: LocalizedStringKey = "Launch at Login"
        static let menuBar: LocalizedStringKey      = "Menu Bar"
        static let showFlag: LocalizedStringKey     = "Flag"
        static let showSession: LocalizedStringKey  = "Session"
        static let showCountdown: LocalizedStringKey = "Countdown"
        static let done: LocalizedStringKey         = "Done"
    }
    enum About {
        static let acknowledgements: LocalizedStringKey = "Acknowledgements"
        static let scheduleData: LocalizedStringKey     = "Schedule data"
        static let flagIcons: LocalizedStringKey        = "Flag icons"
        static let mitLicense: LocalizedStringKey       = "MIT licence"
        static let done: LocalizedStringKey             = "Done"
    }
}
