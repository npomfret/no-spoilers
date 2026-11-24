import SwiftUI

/// Shows both timings when they fit, otherwise sharing their footprint during a flip.
/// Accessibility and Reduce Motion expose both values without waiting for a cycle.
public struct NoSpoilersDepartureBoardText: View {
    private let primary: Text
    private let alternate: Text
    private let face: DepartureBoardCycle.Face
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(primary: Text, alternate: Text, face: DepartureBoardCycle.Face) {
        self.primary = primary
        self.alternate = alternate
        self.face = face
    }

    public var body: some View {
        Group {
            if reduceMotion {
                accessibleContent
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Theme.Space.md) {
                        primary
                        alternate
                    }
                    .fixedSize(horizontal: true, vertical: false)

                    ZStack(alignment: .leading) {
                        primary
                            .modifier(DepartureBoardFaceRotation(degrees: face == .primary ? 0 : -180))
                        alternate
                            .modifier(DepartureBoardFaceRotation(degrees: face == .primary ? 180 : 0))
                    }
                    .animation(Theme.Motion.departureBoardFlip, value: face)
                    .clipped()
                    .accessibilityRepresentation { accessibleContent }
                }
            }
        }
    }

    private var accessibleContent: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
            primary
            alternate
        }
        .accessibilityElement(children: .combine)
    }
}

private struct DepartureBoardFaceRotation: AnimatableModifier {
    var degrees: Double

    var animatableData: Double {
        get { degrees }
        set { degrees = newValue }
    }

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(degrees), axis: (x: 1, y: 0, z: 0), perspective: 0.3)
            // Swap at the edge-on midpoint so neither face appears backwards.
            .opacity(abs(degrees) < 90 ? 1 : 0)
    }
}
