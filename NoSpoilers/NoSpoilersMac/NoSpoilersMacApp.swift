import SwiftUI
import Combine
import AppKit
import OSLog
import NoSpoilersCore

private let flagLog = Logger(subsystem: "pomocorp.NoSpoilers.NoSpoilersMac", category: "flag")

// MARK: - Menu bar image helpers

private func rasterizeNSImage(_ img: NSImage, size pts: CGSize, tintColor: NSColor? = nil) -> NSImage {
    let scale = NSScreen.main?.backingScaleFactor ?? 2.0
    let w = Int(pts.width * scale)
    let h = Int(pts.height * scale)
    let ctx = CGContext(
        data: nil, width: w, height: h,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: scale, y: scale)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    img.draw(in: CGRect(origin: .zero, size: pts))
    if let tint = tintColor {
        tint.set()
        CGRect(origin: .zero, size: pts).fill(using: .sourceAtop)
    }
    NSGraphicsContext.restoreGraphicsState()
    return NSImage(cgImage: ctx.makeImage()!, size: pts)
}

private let f1MenuBarLogo: NSImage =
    rasterizeNSImage(NSImage(resource: ImageResource(name: "f1logo", bundle: noSpoilersCoreBundle)), size: CGSize(width: 32, height: 8), tintColor: NSColor(BrandPalette.signalRed))

// MARK: - Menu bar label view
//
// Rendered inside a real NSHostingView attached to NSStatusItem.button — full SwiftUI pipeline,
// same rendering context as the popover. FlagImage loads and renders correctly here.

private struct MenuBarLabelView: View {
    @ObservedObject var store: ScheduleStore
    @ObservedObject var updateChecker: UpdateChecker
    var onSizeChange: ((CGSize) -> Void)?

    @AppStorage("menuBar.showFlag")      private var showFlag:      Bool = true
    @AppStorage("menuBar.showSession")   private var showSession:   Bool = true
    @AppStorage("menuBar.showCountdown") private var showCountdown: Bool = true
    @State private var tick = Date()
    private let tickTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        let _ = tick
        let pair = store.liveOrNextSessionPair()
        let flagCode = pair?.weekend.countryCode ?? ""
        let showFlagItem = showFlag && !flagCode.isEmpty
        let label = store.menuBarLabel(showSession: showSession, showCountdown: showCountdown)
        HStack(spacing: 4) {
            Image(nsImage: f1MenuBarLogo)
                .interpolation(.none)
            if showFlagItem {
                let _ = flagLog.info("MenuBarLabelView: rendering FlagImage for '\(flagCode)'")
                separatorDot
                FlagImage(countryCode: flagCode, height: 14)
            }
            if !label.isEmpty {
                separatorDot
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
        .background(GeometryReader { g in
            Color.clear
                .onAppear { onSizeChange?(g.size) }
                .onChange(of: g.size) { _, newSize in onSizeChange?(newSize) }
        })
        .onReceive(tickTimer) { t in tick = t }
    }

    private var separatorDot: some View {
        Text("·")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
    }
}

// MARK: - App delegate

private final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let store = ScheduleStore(appGroupID: NoSpoilersConfig.appGroupID)
    private let updateChecker = UpdateChecker()
    private var labelHostingView: NSHostingView<MenuBarLabelView>!
    private var cancellables = Set<AnyCancellable>()
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?
    private var resignActiveObserver: NSObjectProtocol?

    private func makePopoverContentController() -> NSHostingController<MenuBarPopoverRootView> {
        let popoverView = MenuBarPopoverRootView(
            store: store,
            updateChecker: updateChecker,
            dismissPopover: { [weak self] in
                self?.popover.performClose(nil)
            }
        )
        return NSHostingController(rootView: popoverView)
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Accessory policy: pure menu bar app — no Dock icon, no "quit on last window close".
        NSApp.setActivationPolicy(.accessory)
    }


    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        flagLog.info("AppDelegate: applicationDidFinishLaunching")

        // Create NSStatusItem with variable width
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Create label view — FlagImage renders live here (real NSHostingView context)
        let labelView = MenuBarLabelView(store: store, updateChecker: updateChecker) { [weak self] size in
            guard let self else { return }
            flagLog.info("MenuBarLabelView: size changed \(size.width)x\(size.height)")
            // Defer frame update to avoid layoutSubtreeIfNeeded recursion —
            // GeometryReader fires during layout; resizing the NSHostingView here
            // causes a recursive layout cycle.
            DispatchQueue.main.async {
                let padded = CGSize(width: size.width + 8, height: 22)
                self.labelHostingView.frame = NSRect(origin: .zero, size: padded)
                self.statusItem.button?.frame = NSRect(origin: .zero, size: padded)
                self.statusItem.length = padded.width
            }
        }
        labelHostingView = NSHostingView(rootView: labelView)
        let initialSize = labelHostingView.fittingSize
        let paddedInitial = CGSize(width: initialSize.width + 8, height: 22)
        labelHostingView.frame = NSRect(origin: .zero, size: paddedInitial)
        flagLog.info("AppDelegate: initial label size \(initialSize.width)x\(initialSize.height)")

        if let button = statusItem.button {
            button.addSubview(labelHostingView)
            button.frame = labelHostingView.frame
            button.target = self
            button.action = #selector(togglePopover)
        }
        statusItem.length = paddedInitial.width

        // Create popover
        popover = NSPopover()
        popover.contentViewController = makePopoverContentController()
        popover.behavior = .applicationDefined
        popover.delegate = self

        // Initial data load
        Task {
            await store.refresh()
            await updateChecker.check()
        }

        // Periodic refresh every hour
        Timer.publish(every: 3600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in Task { await self?.store.refresh() } }
            .store(in: &cancellables)

    }

    @objc func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            closePopover()
        } else {
            flagLog.info("AppDelegate: showing popover")
            popover.contentViewController = makePopoverContentController()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            startDismissMonitoring()
            // Refresh data when popover opens
            Task {
                await store.refresh()
                await updateChecker.check()
            }
        }
    }

    func popoverDidClose(_ notification: Notification) {
        stopDismissMonitoring()
    }

    private func closePopover() {
        guard popover.isShown else { return }
        popover.close()
    }

    private func startDismissMonitoring() {
        stopDismissMonitoring()

        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            self?.dismissIfNeeded(for: event)
            return event
        }

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            self?.dismissIfNeeded(for: event)
        }

        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func stopDismissMonitoring() {
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
            self.localClickMonitor = nil
        }
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
            self.globalClickMonitor = nil
        }
        if let resignActiveObserver {
            NotificationCenter.default.removeObserver(resignActiveObserver)
            self.resignActiveObserver = nil
        }
    }

    private func dismissIfNeeded(for event: NSEvent) {
        guard popover.isShown else { return }

        let screenPoint = screenPoint(for: event)
        if isInsidePopover(screenPoint) || isInsideStatusItemButton(screenPoint) {
            return
        }

        closePopover()
    }

    private func screenPoint(for event: NSEvent) -> NSPoint {
        if let window = event.window {
            return window.convertPoint(toScreen: event.locationInWindow)
        }
        return NSEvent.mouseLocation
    }

    private func isInsidePopover(_ screenPoint: NSPoint) -> Bool {
        guard let popoverWindow = popover.contentViewController?.view.window else { return false }
        return popoverWindow.frame.contains(screenPoint)
    }

    private func isInsideStatusItemButton(_ screenPoint: NSPoint) -> Bool {
        guard
            let button = statusItem.button,
            let buttonWindow = button.window
        else { return false }

        let pointInWindow = buttonWindow.convertPoint(fromScreen: screenPoint)
        let pointInButton = button.convert(pointInWindow, from: nil)
        return button.bounds.contains(pointInButton)
    }
}

// MARK: - App

@main
struct NoSpoilersMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) { }
        }
    }
}
