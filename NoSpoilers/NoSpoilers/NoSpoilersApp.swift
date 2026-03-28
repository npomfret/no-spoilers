import SwiftUI
import NoSpoilersCore

@main
struct NoSpoilersApp: App {
    @StateObject private var store = ScheduleStore(appGroupID: NoSpoilersConfig.appGroupID)

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
