import SwiftUI

@main
struct AvelaWatchApp: App {
    @State private var model = WatchDashboardModel()

    var body: some Scene {
        WindowGroup { WatchDashboardView(model: model) }
    }
}
