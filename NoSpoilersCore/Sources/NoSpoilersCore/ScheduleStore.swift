import Foundation

/// Shared schedule state. Full implementation in Task 03.
@MainActor
public class ScheduleStore: ObservableObject {
    public static let shared = ScheduleStore()

    @Published public var weekends: [RaceWeekend] = []

    public init() {}

    public func refresh() async {
        // Task 03: fetch → cache → blank state fallback
    }
}
