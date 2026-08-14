import Foundation

/// A time interval split into whole days, hours, minutes and seconds.
///
/// The arithmetic was written out four times — the iOS countdown and "finished ago", the macOS
/// popover countdown and its finished badge, and the menu bar label — with the same modulo
/// expressions and slightly different tier boundaries each time.
///
/// What is *not* shared is which tiers each surface shows: the menu bar has one line of space and
/// stops at hours, the macOS popover ticks in seconds because it is open in front of you, iOS
/// stops at minutes. That divergence is a product decision per surface, so it stays at the call
/// sites, in each target's own `Strings`. Only the arithmetic lives here.
public struct DurationBreakdown {
    /// Whole days.
    public let days: Int
    /// Whole hours within the day — 0...23. Use `totalHours` for "how many hours altogether".
    public let hours: Int
    /// Whole minutes within the hour — 0...59.
    public let minutes: Int
    /// Whole seconds within the minute — 0...59.
    public let seconds: Int

    /// Total whole hours, not capped at a day.
    public let totalHours: Int
    /// Total whole seconds, as supplied.
    public let totalSeconds: Int

    public init(totalSeconds: Int) {
        self.totalSeconds = totalSeconds
        days = totalSeconds / 86_400
        hours = (totalSeconds % 86_400) / 3_600
        minutes = (totalSeconds % 3_600) / 60
        seconds = totalSeconds % 60
        totalHours = totalSeconds / 3_600
    }

    /// Time remaining until `date`. Negative intervals clamp to zero — a countdown that has
    /// elapsed is zero, never a negative reading.
    public init(until date: Date, from now: Date) {
        self.init(totalSeconds: max(0, Int(date.timeIntervalSince(now))))
    }

    /// Time elapsed since `date`, clamped at zero the same way.
    public init(since date: Date, to now: Date) {
        self.init(totalSeconds: max(0, Int(now.timeIntervalSince(date))))
    }

    /// True when the interval has run out, i.e. there is nothing left to count down.
    public var isElapsed: Bool { totalSeconds <= 0 }
}
