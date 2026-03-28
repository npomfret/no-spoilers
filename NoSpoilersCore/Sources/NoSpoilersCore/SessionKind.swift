import Foundation

public enum SessionKind: String, Codable, Hashable, CaseIterable {
    case freePractice1    = "fp1"
    case freePractice2    = "fp2"
    case freePractice3    = "fp3"
    case qualifying       = "qualifying"
    case sprintQualifying = "sprintQualifying"   // camelCase — matches feed key exactly
    case sprint           = "sprint"
    case race             = "gp"                  // feed key is "gp", not "race"

    public var displayName: String {
        switch self {
        case .freePractice1:    return "Free Practice 1"
        case .freePractice2:    return "Free Practice 2"
        case .freePractice3:    return "Free Practice 3"
        case .qualifying:       return "Qualifying"
        case .sprintQualifying: return "Sprint Qualifying"
        case .sprint:           return "Sprint"
        case .race:             return "Race"
        }
    }

    public var defaultDuration: TimeInterval {
        switch self {
        case .freePractice1, .freePractice2, .freePractice3: return 3600
        case .qualifying:       return 3600
        case .sprintQualifying: return 2700
        case .sprint:           return 1800
        case .race:             return 7200
        }
    }
}
