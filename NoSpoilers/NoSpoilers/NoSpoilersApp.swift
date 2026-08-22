import SwiftUI
import NoSpoilersCore

@main
struct NoSpoilersApp: App {
    @StateObject private var store = ScheduleStore(appGroupID: NoSpoilersConfig.appGroupID)
    /// Owned here rather than by `ContentView` so it survives the view being rebuilt, and so
    /// nothing about notifications is reachable from the widget extension, which cannot schedule
    /// them and must not try.
    @StateObject private var alerts = SessionAlertScheduler()

    init() { AppLog.launched(process: "ios") }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(alerts)
        }
    }
}
