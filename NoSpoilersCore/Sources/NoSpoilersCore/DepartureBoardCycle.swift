import Foundation

/// A presentation cycle with a readable hold followed by one top-to-bottom sweep.
/// The caller supplies elapsed time; the cycle owns no clock, timer or mutable state.
public struct DepartureBoardCycle: Sendable {
    public enum Face: Equatable, Sendable {
        case primary
        case alternate
    }

    private let holdDuration: TimeInterval
    public let rowInterval: TimeInterval

    public init(holdDuration: TimeInterval, rowInterval: TimeInterval) {
        precondition(holdDuration.isFinite && holdDuration > 0)
        precondition(rowInterval.isFinite && rowInterval > 0)
        self.holdDuration = holdDuration
        self.rowInterval = rowInterval
    }

    public func face(after elapsed: TimeInterval, rowIndex: Int, rowCount: Int) -> Face {
        precondition(elapsed.isFinite)
        precondition(rowCount > 0 && (0..<rowCount).contains(rowIndex))
        // A wall-clock correction can precede the caller's presentation start.
        guard elapsed >= 0 else { return .primary }
        let sweepDuration = Double(rowCount - 1) * rowInterval
        let halfCycle = holdDuration + sweepDuration
        let position = elapsed.truncatingRemainder(dividingBy: halfCycle * 2)
        let switchesAt = holdDuration + Double(rowIndex) * rowInterval
        if position < halfCycle {
            return position >= switchesAt ? .alternate : .primary
        }
        return position >= halfCycle + switchesAt ? .primary : .alternate
    }
}
