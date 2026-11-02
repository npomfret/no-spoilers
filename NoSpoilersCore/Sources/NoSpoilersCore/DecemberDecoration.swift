import Foundation

/// A recurring local Gregorian date window, supplied by the app/widget composition root.
public enum DecemberDecoration {
    public struct Configuration: Equatable, Sendable {
        public let startMonth: Int
        public let startDay: Int
        public let endMonth: Int
        public let endDay: Int

        /// Both dates are inclusive. Defaults cover 1–26 December annually.
        public init(startMonth: Int = 12, startDay: Int = 1, endMonth: Int = 12, endDay: Int = 26) {
            let calendar = Calendar(identifier: .gregorian)
            for (month, day) in [(startMonth, startDay), (endMonth, endDay)] {
                guard let date = calendar.date(from: DateComponents(year: 2000, month: month, day: day)) else {
                    preconditionFailure("Decoration dates must be valid Gregorian month/day values")
                }
                precondition(calendar.component(.month, from: date) == month && calendar.component(.day, from: date) == day,
                             "Decoration dates must be valid Gregorian month/day values")
            }
            self.startMonth = startMonth
            self.startDay = startDay
            self.endMonth = endMonth
            self.endDay = endDay
        }
    }

    public static func isActive(at date: Date, timeZone: TimeZone, configuration: Configuration) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let current = calendar.component(.month, from: date) * 100 + calendar.component(.day, from: date)
        let start = configuration.startMonth * 100 + configuration.startDay
        let end = configuration.endMonth * 100 + configuration.endDay
        return start <= end ? current >= start && current <= end : current >= start || current <= end
    }

    /// The start and midnight after the inclusive end, even when no session is scheduled.
    public static func boundaries(after date: Date, through end: Date, timeZone: TimeZone,
                                  configuration: Configuration) -> [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let firstYear = calendar.component(.year, from: date)
        let lastYear = calendar.component(.year, from: end)
        let crossesYear = configuration.endMonth * 100 + configuration.endDay
            < configuration.startMonth * 100 + configuration.startDay
        return ((firstYear - 1)...lastYear).flatMap { year -> [Date] in
            guard let start = calendar.date(from: DateComponents(year: year, month: configuration.startMonth, day: configuration.startDay)),
                  let lastDay = calendar.date(from: DateComponents(year: year + (crossesYear ? 1 : 0), month: configuration.endMonth, day: configuration.endDay)),
                  let finish = calendar.date(byAdding: .day, value: 1, to: lastDay) else {
                preconditionFailure("Configured decoration boundaries must exist")
            }
            return [start, finish]
        }
        .filter { $0 > date && $0 <= end }
        .sorted()
    }
}
