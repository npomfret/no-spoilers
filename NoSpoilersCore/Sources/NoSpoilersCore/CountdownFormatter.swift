import Foundation

/// Renders the *units* of a countdown — `3d 4h`, `15m 30s` — and stops there.
///
/// The phrasing around them stays with the caller: iOS wraps this in "in …",
/// the macOS popover shows it bare, and each keeps its own word for a countdown
/// that has run out. That split is what makes this shareable at all, because the
/// wrapping is the part that differs and the part a translator has to reorder.
///
/// **Two surfaces use it, not three.** `DurationBreakdown` already states that
/// which tiers a surface shows is a product decision per surface, and that only
/// the arithmetic is shared. This does not overturn that — it shares the one
/// rule iOS and the popover turned out to have in common, and the *rule* is
/// still supplied per surface as `units` and `floor`.
///
/// The menu bar deliberately does not use this. It shows `in 3d`, then
/// `2h 15m`, then `15m` — one unit, two, then one again — which no value of
/// `units` produces. Folding it in would mean changing what the menu bar shows,
/// in the one surface that shares a single line with the app icon and a flag.
/// See `ScheduleStore.menuBarLabel`.
public struct CountdownFormatter {
    /// The finest unit a surface is willing to show.
    ///
    /// iOS stops at minutes because the screen is glanced at and a ticking
    /// seconds field would invalidate every page once a second. The popover goes
    /// to seconds because it is open in front of you, where a static minutes
    /// reading looks frozen.
    public enum Floor {
        case minutes
        case seconds
    }

    /// How many units to show, counting from the largest one that is non-zero.
    private let units: Int
    private let floor: Floor

    public init(units: Int, floor: Floor) {
        precondition(units >= 1, "a countdown showing no units is not a countdown")
        self.units = units
        self.floor = floor
    }

    /// The units of `remaining`, joined by spaces.
    ///
    /// Counting starts at the largest non-zero unit, so a countdown of two days
    /// reads `2d 3h` and one of twenty minutes reads `20m 30s` — the leading
    /// zeroes are dropped rather than printed. Whether the caller has already
    /// handled an elapsed countdown is the caller's business; this renders
    /// whatever it is handed.
    ///
    /// **When every unit is zero the floor unit is shown alone**, giving `0m`
    /// under a minute on iOS. That is not a fallback for absent data — it is the
    /// reading for a real interval that is smaller than anything this surface
    /// displays, and it is what the iOS ladder already produced.
    public func string(for remaining: DurationBreakdown) -> String {
        var ladder: [(value: Int, render: (Int) -> String)] = [
            (remaining.days, Strings.Schedule.durationDays),
            (remaining.hours, Strings.Schedule.durationHours),
            (remaining.minutes, Strings.Schedule.durationMinutes),
        ]
        if floor == .seconds {
            ladder.append((remaining.seconds, Strings.Schedule.durationSeconds))
        }

        let start = ladder.firstIndex { $0.value > 0 } ?? ladder.count - 1
        return ladder[start...]
            .prefix(units)
            .map { $0.render($0.value) }
            .joined(separator: " ")
    }
}
