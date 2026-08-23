import Foundation

/// The three buckets people actually think in when choosing what to be told about.
///
/// Seven per-session switches was one row per `SessionKind`, which is the schedule's vocabulary
/// rather than the reader's: nobody wants Practice 2 and not Practice 3. The preference is stored
/// as groups for the same reason it is shown as groups — a per-kind store behind a grouped UI has
/// states the UI cannot draw, and the first half-selected group would have to be rendered as
/// something, silently.
///
/// **`SessionAlertPlanner` still takes `Set<SessionKind>` and does not know this type exists.**
/// Planning is per session and grouping is a preference, so the expansion happens once at the
/// boundary where preferences are read. Widening the planner to speak in groups would put the
/// mapping inside the pure logic and give the same fact two homes.
public enum SessionAlertGroup: String, Codable, Hashable, CaseIterable {
    case practice
    case qualifying
    case races

    public var displayName: String {
        switch self {
        case .practice:   return Strings.SessionNames.Group.practice
        case .qualifying: return Strings.SessionNames.Group.qualifying
        case .races:      return Strings.SessionNames.Group.races
        }
    }

    /// What the group covers, and what it says it covers, are the same sentence.
    ///
    /// The settings row needs to name the sessions because two of the three are not obvious:
    /// Sprint Qualifying is qualifying and the Sprint is a race, and a reader who assumes
    /// otherwise turns off the wrong one.
    public var summary: String {
        kinds.sorted { $0.sortOrder < $1.sortOrder }
            .map(\.displayName)
            .joined(separator: ", ")
    }

    /// Derived from `SessionKind.alertGroup` rather than listed again here.
    ///
    /// One direction is written and the other is computed, so the two cannot disagree. A new
    /// `SessionKind` fails to compile in exactly one place — the switch that assigns it a group —
    /// and appears here the moment it is given one.
    public var kinds: Set<SessionKind> {
        Set(SessionKind.allCases.filter { $0.alertGroup == self })
    }
}

public extension SessionAlertGroup {
    /// Every kind covered by a set of groups: what the planner is actually given.
    static func kinds(in groups: Set<SessionAlertGroup>) -> Set<SessionKind> {
        groups.reduce(into: Set<SessionKind>()) { $0.formUnion($1.kinds) }
    }
}

public extension SessionKind {
    /// Which switch in the alert settings turns this session on.
    ///
    /// Exhaustive on purpose: adding a session kind should not silently produce one that no
    /// setting can reach, which is a session nobody can be told about and nobody can find out why.
    var alertGroup: SessionAlertGroup {
        switch self {
        case .freePractice1, .freePractice2, .freePractice3:
            return .practice
        case .qualifying, .sprintQualifying:
            return .qualifying
        case .sprint, .race:
            return .races
        }
    }

    /// Weekend running order, for listing a group's sessions the way they happen.
    var sortOrder: Int {
        switch self {
        case .freePractice1:    return 0
        case .freePractice2:    return 1
        case .freePractice3:    return 2
        case .sprintQualifying: return 3
        case .sprint:           return 4
        case .qualifying:       return 5
        case .race:             return 6
        }
    }
}
