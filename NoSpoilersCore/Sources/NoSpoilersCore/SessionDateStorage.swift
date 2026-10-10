import Foundation

/// Dates keyed by `Session.id`, in the `[String: Double]` form already on users' devices.
///
/// The one encoding for `SessionEndConfirmer`'s confirmed ends and `SessionAlertScheduler`'s
/// announced ones, so the two cannot drift into different spellings of the same data.
extension UserDefaults {
    func sessionDates(forKey key: String) -> [String: Date] {
        // An absent key is a first launch, or nothing confirmed yet: an empty record is the answer.
        guard let raw = dictionary(forKey: key) as? [String: Double] else { return [:] }
        return raw.mapValues { Date(timeIntervalSince1970: $0) }
    }

    func setSessionDates(_ dates: [String: Date], forKey key: String) {
        set(dates.mapValues { $0.timeIntervalSince1970 }, forKey: key)
    }
}
