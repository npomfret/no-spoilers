import SwiftUI

// MARK: - Strings
// All user-facing text in the macOS app, centralised here for future localisation.
// Text and Button views accept LocalizedStringKey directly, so Text(Strings.Foo.bar)
// will automatically pick up translations once a Localizable.strings file is added.
//
// Dynamic strings (countdowns, "Finished Xh ago") are format strings — extract those
// when adding translations using String(localized:) with interpolation.

enum Strings {
    enum Popover {
        static let inProgress: LocalizedStringKey   = "In Progress"
        static let updateAvailable: LocalizedStringKey = "Update available"
        static let brewUpgrade: LocalizedStringKey  = "brew upgrade no-spoilers"
        static let offSeason: LocalizedStringKey    = "Off season"
        static let noSessions: LocalizedStringKey   = "No upcoming sessions found"
        static let settings: LocalizedStringKey     = "Settings"
        static let quit: LocalizedStringKey         = "Quit"
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
}
