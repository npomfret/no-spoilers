import SwiftUI

/// One drawing shared by both apps and widget snapshots. It owns no clock or particle state:
/// frames are deterministic values of the supplied opening date and SwiftUI's timeline date.
public struct NoSpoilersDecemberDecoration: View {
    public enum Layer {
        case background
        case foreground
    }

    private let canvas: Theme.Canvas
    private let layer: Layer
    private let startedAt: Date
    private let animated: Bool
    private let contentMargins: EdgeInsets

    public init(canvas: Theme.Canvas, layer: Layer, startedAt: Date, animated: Bool, contentMargins: EdgeInsets) {
        self.canvas = canvas
        self.layer = layer
        self.startedAt = startedAt
        self.animated = animated
        self.contentMargins = contentMargins
    }

    public var body: some View {
        Group {
            if animated {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                    drawing(elapsed: max(0, timeline.date.timeIntervalSince(startedAt)))
                }
            } else {
                // Widget archives and Reduce Motion have a complete still scene, not a timer.
                drawing(elapsed: 22)
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var isWidget: Bool {
        switch canvas {
        case .iosApp, .macPopover: return false
        case .widgetSmall, .widgetMedium, .widgetLarge: return true
        }
    }

    private func drawing(elapsed: TimeInterval) -> some View {
        Canvas { context, size in
            let reserve = Theme.December.snowReserve(canvas, bottomMargin: contentMargins.bottom)
            let depth = Self.driftDepth(canvas: canvas, elapsed: elapsed, bottomMargin: contentMargins.bottom)
            drawSnow(context: &context, size: size, elapsed: elapsed, reserve: reserve, depth: depth)
            if layer == .foreground {
                drawLights(context: &context, size: size, elapsed: elapsed)
                drawDrift(context: &context, size: size, depth: depth)
            }
        }
    }

    private func seed(_ index: Int, _ salt: Int) -> Double {
        let value = sin(Double(index) * 127.1 + Double(salt) * 311.7) * 43758.5453
        return value - floor(value)
    }

    static func driftDepth(canvas: Theme.Canvas, elapsed: TimeInterval, bottomMargin: CGFloat) -> CGFloat {
        let reserve = Theme.December.snowReserve(canvas, bottomMargin: bottomMargin)
        switch canvas {
        case .iosApp, .macPopover: return min(reserve - 24, 38 + max(0, elapsed) * 1.7)
        case .widgetSmall, .widgetMedium, .widgetLarge: return min(36, reserve * 0.5)
        }
    }

    private static func snowSurface(x: CGFloat, size: CGSize, depth: CGFloat) -> CGFloat {
        let fraction = x / max(1, size.width)
        let waveScale = min(1, depth / 24)
        return size.height - depth - waveScale * (8 * sin(fraction * 4.8 + 0.7) + 5 * sin(fraction * 10.7 + 1.1))
    }

    static func driftY(x: CGFloat, size: CGSize, depth: CGFloat, offset: CGFloat) -> CGFloat {
        let scale = min(1, depth / 24)
        return snowSurface(x: x, size: size, depth: depth) + offset * scale
            + 3 * scale * sin(x / max(1, size.width) * 8 + offset)
    }

    private func drawSnow(context: inout GraphicsContext, size: CGSize, elapsed: Double, reserve: CGFloat, depth: CGFloat) {
        let count = isWidget ? 34 : 80
        for index in 0..<count {
            let near = index.isMultiple(of: 5)
            let radius = near ? 1.7 + seed(index, 2) * 1.3 : 0.5 + seed(index, 2) * 0.8
            let speed = near ? 24 + seed(index, 3) * 12 : 10 + seed(index, 3) * 13
            let y = (seed(index, 1) * (size.height + 35) + elapsed * speed)
                .truncatingRemainder(dividingBy: size.height + 35) - 20
            let drift = sin(elapsed * 0.31 + seed(index, 5) * 8) * (near ? 12 : 7)
            let x = (seed(index, 4) * size.width + drift + size.width)
                .truncatingRemainder(dividingBy: max(1, size.width))
            guard y < Self.snowSurface(x: x, size: size, depth: depth) - radius else { continue }
            let left = isWidget ? contentMargins.leading : 14
            let right = isWidget ? contentMargins.trailing : 14
            let inForeground = near && (x < left || x > size.width - right || y > size.height - reserve)
            guard (layer == .foreground) == inForeground else { continue }
            let opacity = near ? 0.75 : 0.32 + seed(index, 6) * 0.33
            let flake = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
            context.fill(flake, with: .color(BrandPalette.decemberSnow.opacity(opacity)))
        }
    }

    private func drawLights(context: inout GraphicsContext, size: CGSize, elapsed: Double) {
        let small = canvas == .widgetSmall
        // WidgetKit margins vary across hosts. Scale the entire string into the actual top margin
        // plus the reserved inset, without taking space from existing compact-widget text.
        let availableTop = Theme.December.topInset(canvas) + contentMargins.top
        let scale: CGFloat = isWidget ? min(1, max(0, availableTop - 1) / 35) : 1
        let count = small ? 5 : (canvas == .iosApp ? 12 : 10)
        let colours = [BrandPalette.decemberWarm, BrandPalette.decemberRed, BrandPalette.decemberGreen,
                       BrandPalette.decemberBlue, BrandPalette.decemberAmber]
        let drop: CGFloat = 12 * scale
        func cordY(_ x: CGFloat) -> CGFloat {
            5 * scale + drop * (0.5 - 0.5 * cos(x / max(1, size.width) * .pi * 6))
        }
        var cord = Path()
        cord.move(to: CGPoint(x: -5, y: cordY(-5)))
        for x in stride(from: CGFloat(-3), through: size.width + 5, by: 2) {
            cord.addLine(to: CGPoint(x: x, y: cordY(x)))
        }
        context.stroke(cord, with: .color(BrandPalette.decemberText.opacity(0.65)), lineWidth: 1.2)

        for index in 0..<count {
            let x = size.width * (0.025 + CGFloat(index) * 0.95 / CGFloat(count - 1))
            let y = cordY(x)
            let brightness = 0.4 + 0.6 * pow(sin(elapsed * (0.7 + seed(index, 7) * 0.7) + Double(index) * 1.9), 2)
            let colour = colours[index % colours.count]
            let center = CGPoint(x: x, y: y + 11 * scale)
            let haloRadius = 27 * scale
            let halo = Path(ellipseIn: CGRect(x: x - haloRadius, y: center.y - haloRadius,
                                              width: haloRadius * 2, height: haloRadius * 2))
            context.fill(halo, with: .radialGradient(
                Gradient(stops: [.init(color: colour.opacity(0.56 * brightness), location: 0),
                                 .init(color: colour.opacity(0.21 * brightness), location: 0.25),
                                 .init(color: colour.opacity(0), location: 1)]),
                center: center, startRadius: 0, endRadius: haloRadius
            ))
            context.fill(Path(CGRect(x: x - 2.5 * scale, y: y + scale, width: 5 * scale, height: 5 * scale)),
                         with: .color(BrandPalette.decemberText.opacity(0.5)))
            let radius: CGFloat = (small ? 3 : 3.8) * scale
            let bulb = Path(ellipseIn: CGRect(x: x - radius, y: y + 4.6 * scale,
                                              width: radius * 2, height: 12.8 * scale))
            context.fill(bulb, with: .linearGradient(
                Gradient(colors: [colour.opacity(brightness), colour.opacity(brightness * 0.75), colour.opacity(brightness)]),
                startPoint: CGPoint(x: x - 4 * scale, y: y), endPoint: CGPoint(x: x + 4 * scale, y: y + 13 * scale)
            ))
            let glint = Path(ellipseIn: CGRect(x: x - 1.5 * scale, y: y + 6.3 * scale,
                                               width: 1.5 * scale, height: 5.4 * scale))
            context.fill(glint, with: .color(BrandPalette.white.opacity(0.8 * brightness)))
        }
    }

    private func drawDrift(context: inout GraphicsContext, size: CGSize, depth: CGFloat) {
        let layers: [(CGFloat, Color, Color)] = [
            (-4, BrandPalette.decemberSnowShadow, BrandPalette.decemberSkyTop),
            (4, BrandPalette.decemberSnow, BrandPalette.decemberSnowBase),
            (19, BrandPalette.white, BrandPalette.decemberSnow)
        ]
        for (offset, top, bottom) in layers {
            var drift = Path()
            drift.move(to: CGPoint(x: -2, y: size.height + 2))
            for x in stride(from: CGFloat(-2), through: size.width + 4, by: 3) {
                let y = Self.driftY(x: x, size: size, depth: depth, offset: offset)
                drift.addLine(to: CGPoint(x: x, y: y))
            }
            drift.addLine(to: CGPoint(x: size.width + 4, y: size.height + 2))
            drift.closeSubpath()
            context.fill(drift, with: .linearGradient(
                Gradient(colors: [top, bottom]),
                startPoint: CGPoint(x: 0, y: size.height - depth), endPoint: CGPoint(x: 0, y: size.height)
            ))
        }
    }
}
