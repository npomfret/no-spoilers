import SwiftUI

// MARK: - Strings
// All user-facing text in the widget, centralised here for future localisation.
// Text and Button views accept LocalizedStringKey directly, so Text(Strings.Foo.bar)
// will automatically pick up translations once a Localizable.strings file is added.
//
// Dynamic strings (countdowns, "+N more sessions") are centralised as format functions below.
// Swap to String(localized:) with interpolation when a Localizable.strings file is added.

enum Strings {
    enum Sessions {
        static let inProgress: LocalizedStringKey         = "In Progress"
        static let finished: LocalizedStringKey           = "Finished"
        static func roundLabel(_ round: Int) -> String    { "R\(round)" }
    }
    enum Widget {
        static let comingUp: LocalizedStringKey           = "Next up"
        static let displayName: LocalizedStringKey        = "No Spoilers"
        static let widgetDescription: LocalizedStringKey  = "Grand Prix weekend sessions — never the result."
        static func moreSessions(_ count: Int) -> String  { "+\(count) more session\(count == 1 ? "" : "s")" }
        static func dateRange(start: String, end: String) -> String { "\(start) → \(end)" }
    }
    enum OffSeason {
        static let badge: LocalizedStringKey              = "Off-season"
        static let body: LocalizedStringKey               = "The next race weekend will appear here as soon as it gets close enough to matter."
    }
    enum Error {
        static let unavailableTitle: LocalizedStringKey   = "Schedule unavailable"
        static let unavailableBody: LocalizedStringKey    = "Open the app to refresh the shared schedule cache."
    }
}
