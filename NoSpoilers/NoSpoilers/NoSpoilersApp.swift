import SwiftUI
import WidgetKit
import NoSpoilersCore

@main
struct NoSpoilersApp: App {
    @StateObject private var store = ScheduleStore(appGroupID: NoSpoilersConfig.appGroupID)
    /// Owned here rather than by `ContentView` so it survives the view being rebuilt, and so
    /// nothing about notifications is reachable from the widget extension, which cannot schedule
    /// them and must not try.
    @StateObject private var alerts = SessionAlertScheduler()
    /// Owned here for the same reason, and used from the same three foreground moments. A Live
    /// Activity can only be started while the app is in the foreground, so there is nowhere else
    /// it could live.
    @StateObject private var activities = SessionActivityController()

    init() {
        AppLog.launched(process: "ios")
        // WidgetKit keeps showing the previous build's archived timeline after an update until
        // something asks for a reload, and `ScheduleStore` only asks when the schedule changes.
        // So the first launch on a new build asks once, here, before any view exists. Placement
        // does not matter: `reloadAllTimelines` on a device with no widget is a no-op. See
        // `InstalledBuild`.
        if InstalledBuild.changed(to: AppVersion.build) {
            WidgetCenter.shared.reloadAllTimelines()
            AppLog.widget.notice("reload requested for new build", ["build": AppVersion.build])
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(alerts)
                .environmentObject(activities)
        }
    }
}
