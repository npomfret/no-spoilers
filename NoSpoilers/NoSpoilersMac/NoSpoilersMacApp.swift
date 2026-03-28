import SwiftUI
import Combine
import NoSpoilersCore

private let appGroupID = "group.pomocorp.no-spoilers"

@main
struct NoSpoilersMacApp: App {
    @StateObject private var store = ScheduleStore(appGroupID: appGroupID)
    private let refreshTimer = Timer.publish(every: 6 * 3600, on: .main, in: .common).autoconnect()

    var body: some Scene {
        MenuBarExtra(store.menuBarLabel) {
            WeekendPopoverView(store: store)
                .frame(width: 280)
                .task { await store.refresh() }
                .onReceive(refreshTimer) { _ in Task { await store.refresh() } }
        }
        .menuBarExtraStyle(.window)
    }
}
