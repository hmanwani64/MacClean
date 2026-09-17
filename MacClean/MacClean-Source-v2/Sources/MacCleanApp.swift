import SwiftUI

@main
struct MacCleanApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Image(systemName: "sparkles")
        }
        .menuBarExtraStyle(.window)

        Window("MacClean", id: "dashboard") {
            DashboardView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 620)
        }
        .windowResizability(.contentSize)
    }
}
