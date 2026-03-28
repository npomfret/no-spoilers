import Foundation

/// Denormalised view of a single session — derived from `RaceWeekend`, never stored directly.
public struct Session: Identifiable, Hashable {
    public var id: String { "\(round)-\(kind.rawValue)" }
    public let round: Int
    public let grandPrixName: String
    public let location: String
    public let kind: SessionKind
    public let startsAt: Date
    public var endsAt: Date { startsAt.addingTimeInterval(kind.defaultDuration) }

    public init(round: Int, grandPrixName: String, location: String, kind: SessionKind, startsAt: Date) {
        self.round         = round
        self.grandPrixName = grandPrixName
        self.location      = location
        self.kind          = kind
        self.startsAt      = startsAt
    }
}
