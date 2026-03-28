import SwiftUI
import Combine
import AppKit
import NoSpoilersCore

private let appGroupID = "group.pomocorp.no-spoilers"

// MARK: - F1 Logo Shape (120 × 30 coordinate space)

struct F1Logo: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 120
        let sy = rect.height / 30
        let t = CGAffineTransform(scaleX: sx, y: sy)
            .translatedBy(x: rect.minX / sx, y: rect.minY / sy)
        var p = Path()

        // TM "M"
        p.move(to: .init(x: 101.086812, y: 30)); p.addLine(to: .init(x: 101.711812, y: 30))
        p.addLine(to: .init(x: 101.711812, y: 27.106875)); p.addLine(to: .init(x: 101.722437, y: 27.106875))
        p.addLine(to: .init(x: 102.761812, y: 30)); p.addLine(to: .init(x: 103.302437, y: 30))
        p.addLine(to: .init(x: 104.341812, y: 27.106875)); p.addLine(to: .init(x: 104.352437, y: 27.106875))
        p.addLine(to: .init(x: 104.352437, y: 30)); p.addLine(to: .init(x: 104.977437, y: 30))
        p.addLine(to: .init(x: 104.977437, y: 26.25125)); p.addLine(to: .init(x: 104.063687, y: 26.25125))
        p.addLine(to: .init(x: 103.055562, y: 29.18625)); p.addLine(to: .init(x: 103.044937, y: 29.18625))
        p.addLine(to: .init(x: 102.011187, y: 26.25125)); p.addLine(to: .init(x: 101.086812, y: 26.25125))
        p.closeSubpath()

        // TM "T"
        p.move(to: .init(x: 97.6274375, y: 26.818125)); p.addLine(to: .init(x: 98.8136875, y: 26.818125))
        p.addLine(to: .init(x: 98.8136875, y: 30)); p.addLine(to: .init(x: 99.4699375, y: 30))
        p.addLine(to: .init(x: 99.4699375, y: 26.818125)); p.addLine(to: .init(x: 100.661812, y: 26.818125))
        p.addLine(to: .init(x: 100.661812, y: 26.25125)); p.addLine(to: .init(x: 97.6274375, y: 26.25125))
        p.closeSubpath()

        // "1"
        p.move(to: .init(x: 89.9999375, y: 30)); p.addLine(to: .init(x: 119.999937, y: 0))
        p.addLine(to: .init(x: 101.943687, y: 0)); p.addLine(to: .init(x: 71.9443125, y: 30))
        p.closeSubpath()

        // "F" + arrow
        p.move(to: .init(x: 85.6986875, y: 13.065)); p.addLine(to: .init(x: 49.3818125, y: 13.065))
        p.addCurve(to: .init(x: 31.6361875, y: 18.3925),
                   control1: .init(x: 38.3136875, y: 13.065), control2: .init(x: 36.3768125, y: 13.651875))
        p.addCurve(to: .init(x: 20.0005625, y: 30),
                   control1: .init(x: 27.2024375, y: 22.82625), control2: .init(x: 20.0005625, y: 30))
        p.addLine(to: .init(x: 35.7324375, y: 30)); p.addLine(to: .init(x: 39.4855625, y: 26.246875))
        p.addCurve(to: .init(x: 48.4068125, y: 23.52375),
                   control1: .init(x: 41.9530625, y: 23.779375), control2: .init(x: 43.2255625, y: 23.52375))
        p.addLine(to: .init(x: 75.2405625, y: 23.52375))
        p.closeSubpath()

        // Main chevron
        p.move(to: .init(x: 31.1518125, y: 16.253125))
        p.addCurve(to: .init(x: 16.9130625, y: 30),
                   control1: .init(x: 27.8774375, y: 19.3425), control2: .init(x: 20.7530625, y: 26.263125))
        p.addLine(to: .init(x: 0, y: 30))
        p.addCurve(to: .init(x: 21.0849375, y: 9.0725),
                   control1: .init(x: 0, y: 30), control2: .init(x: 13.5524375, y: 16.486875))
        p.addCurve(to: .init(x: 46.9486875, y: 0),
                   control1: .init(x: 28.8455625, y: 1.685), control2: .init(x: 32.7143125, y: 0))
        p.addLine(to: .init(x: 98.7643125, y: 0)); p.addLine(to: .init(x: 87.5449375, y: 11.21875))
        p.addLine(to: .init(x: 48.0011875, y: 11.21875))
        p.addCurve(to: .init(x: 31.1518125, y: 16.253125),
                   control1: .init(x: 37.9993125, y: 11.21875), control2: .init(x: 35.7518125, y: 11.911875))
        p.closeSubpath()

        return p.applying(t)
    }
}

// MARK: - Rasterise F1 logo to NSImage (approach from example-project)

private let f1MenuBarLogo: NSImage = {
    let pts  = CGSize(width: 32, height: 8)
    let scale: CGFloat = 2
    let px   = CGSize(width: pts.width * scale, height: pts.height * scale)

    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(px.width), pixelsHigh: Int(px.height),
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return NSImage(size: pts) }
    rep.size = pts

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    if let ctx = NSGraphicsContext.current?.cgContext {
        // NSGraphicsContext(bitmapImageRep:) uses point coordinates (32×8 pt),
        // with 2× scale already baked in. Draw in point space, flip y to match SwiftUI.
        ctx.translateBy(x: 0, y: pts.height)
        ctx.scaleBy(x: 1, y: -1)
        let path = F1Logo().path(in: CGRect(origin: .zero, size: pts))
        ctx.setFillColor(CGColor(red: 0.93, green: 0, blue: 0, alpha: 1))
        ctx.addPath(path.cgPath)
        ctx.fillPath()
    }

    let img = NSImage(size: pts)
    img.addRepresentation(rep)
    return img
}()

// MARK: - App

@main
struct NoSpoilersMacApp: App {
    @StateObject private var store = ScheduleStore(appGroupID: appGroupID)
    @StateObject private var updateChecker = UpdateChecker()
    private let refreshTimer = Timer.publish(every: 6 * 3600, on: .main, in: .common).autoconnect()

    @AppStorage("menuBar.showFlag")      private var showFlag:      Bool = true
    @AppStorage("menuBar.showSession")   private var showSession:   Bool = true
    @AppStorage("menuBar.showCountdown") private var showCountdown: Bool = true

    var body: some Scene {
        MenuBarExtra {
            WeekendPopoverView(store: store, updateChecker: updateChecker)
                .frame(width: 300)
                .task { await store.refresh() }
                .task { await updateChecker.check() }
                .onReceive(refreshTimer) { _ in Task { await store.refresh() } }
        } label: {
            HStack(spacing: 5) {
                Image(nsImage: f1MenuBarLogo)
                    .interpolation(.none)
                let label = store.menuBarLabel(showFlag: showFlag, showSession: showSession, showCountdown: showCountdown)
                if !label.isEmpty {
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                }
                if updateChecker.isUpdateAvailable {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 5, height: 5)
                }
            }
            .fixedSize()
        }
        .menuBarExtraStyle(.window)

        Window("Settings", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
    }
}
