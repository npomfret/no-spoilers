import SwiftUI
import NoSpoilersCore

// MARK: - Strings
// All user-facing text in the widget, centralised here for future localisation.
// Text and Button views accept LocalizedStringKey directly, so Text(Strings.Foo.bar)
// will automatically pick up translations once a Localizable.strings file is added.
//
// Dynamic strings (countdowns, "+N earlier sessions") are centralised as format functions below.
// Swap to String(localized:) with interpolation when a Localizable.strings file is added.

enum Strings {
    enum Sessions {
        static let sprintQualifyingAbbreviation = "SQ"
        static func shortName(_ kind: SessionKind) -> String {
            kind == .sprintQualifying ? sprintQualifyingAbbreviation : kind.shortName
        }
        static func upcomingTiming(_ startsAt: Date, dateOnNewLine: Bool = false, concise: Bool = false) -> Text {
            let countdown: Text
            if concise {
                countdown = Text(
                    .currentDate,
                    format: Date.AnchoredRelativeFormatStyle(
                        anchor: startsAt, allowedFields: [.day, .hour, .minute],
                        presentation: .numeric, unitsStyle: .abbreviated,
                        capitalizationContext: .middleOfSentence
                    )
                )
            } else {
                countdown = Text("in \(Text(startsAt, style: .relative))")
            }
            let date = NoSpoilersCore.Strings.Schedule.sessionDateTime(startsAt, style: .widget)
            if dateOnNewLine {
                return Text("\(countdown)\n(\(date))")
            }
            return Text("\(countdown) (\(date))")
        }
        static func sessionUpcomingTiming(_ kind: SessionKind, startsAt: Date) -> Text {
            let name = Text(shortName(kind))
            return Text("\(name) \(upcomingTiming(startsAt, concise: true))")
        }
        static let finished: LocalizedStringKey           = "Finished"
        static let statusUnconfirmed: LocalizedStringKey  = "Status unconfirmed"
        static let scheduledStart: LocalizedStringKey     = "Scheduled start"
        static let countdownToScheduledStart: LocalizedStringKey = "Countdown to scheduled start"
    }
    enum Widget {
        static let widgetDescription: LocalizedStringKey  = "Grand Prix weekend sessions — never the result."
        static func earlierSessions(_ count: Int) -> String { "+\(count) earlier session\(count == 1 ? "" : "s")" }
    }
    enum OffSeason {
        static let badge: LocalizedStringKey              = "Off-season"
        static let body: LocalizedStringKey               = "The next race weekend will appear here as soon as it gets close enough to matter."
    }
    enum Error {
        static let unavailableBody: LocalizedStringKey    = "Open the app to refresh the shared schedule cache."
    }
}
