import SwiftUI
import NoSpoilersCore

@main
struct NoSpoilersApp: App {
    @StateObject private var store = ScheduleStore(appGroupID: NoSpoilersConfig.appGroupID)

    init() { AppLog.launched(process: "ios") }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
