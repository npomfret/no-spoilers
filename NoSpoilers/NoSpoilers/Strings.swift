import SwiftUI

// MARK: - Strings
// All user-facing text in the iOS app, centralised here for future localisation.
// Text and Button views accept LocalizedStringKey directly, so Text(Strings.Foo.bar)
// will automatically pick up translations once a Localizable.strings file is added.
//
// Dynamic strings (countdowns, "Round N", "Next session in Xd Yh") are centralised as format
// functions below. Swap to String(localized:) with interpolation when a Localizable.strings file is added.

enum Strings {
    enum App {
        static let name: LocalizedStringKey               = "No Spoilers"
    }
    enum Sessions {
        static let header: LocalizedStringKey             = "Sessions"
        static let comingUp: LocalizedStringKey           = "Coming up..."
        static let weekendComplete: LocalizedStringKey    = "Weekend complete"
        static let inProgress: LocalizedStringKey         = "In Progress"
        static func weekendCompleteStatus() -> String     { "Weekend complete" }
        static func roundLabel(_ round: Int) -> String    { "R\(round)" }
        static func roundLong(_ round: Int) -> String     { "Round \(round)" }
        static let countdownNow: String                   = "now"
        static func countdownDaysHours(_ d: Int, _ h: Int) -> String    { "in \(d)d \(h)h" }
        static func countdownHoursMinutes(_ h: Int, _ m: Int) -> String { "in \(h)h \(m)m" }
        static func countdownMinutes(_ m: Int) -> String  { "in \(m)m" }
        static func durationHours(_ h: Int) -> String        { "\(h)h" }
        static func durationMinutes(_ m: Int) -> String      { "\(m)m" }
        static func finishedAgo(_ time: String) -> String    { "Finished \(time)" }
        static func sessionFinished(name: String, ago: String) -> String    { "\(name) finished \(ago) ago" }
        static func sessionInProgress(_ name: String) -> String             { "\(name) is in progress" }
        static func sessionUpcoming(name: String, countdown: String) -> String { "\(name) \(countdown)" }
        static func dateRange(start: String, end: String) -> String         { "\(start) to \(end)" }
    }
    enum Error {
        static let unavailableTitle: LocalizedStringKey   = "Schedule unavailable"
        static let unavailableBody: LocalizedStringKey    = "Pull to refresh or open the app again to update the shared widget cache."
    }
}
