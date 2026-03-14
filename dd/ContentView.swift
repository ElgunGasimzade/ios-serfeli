import SwiftUI

struct ContentView: View {
    @EnvironmentObject var localization: LocalizationManager
    @ObservedObject private var routeService = RouteCacheService.shared
    @State private var selection = 0
    @Environment(\.scenePhase) private var scenePhase

    let tabSwitchPub = NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToPFM"))

    var body: some View {
        TabView(selection: $selection) {
            HomeScreen()
                .tabItem {
                    Label("Home".localized, systemImage: "house")
                }
                .tag(0)

            WatchlistScreen()
                .tabItem {
                    Label("Watchlist".localized, systemImage: "eye")
                }
                .tag(1)

            ScanCaptureScreen()
                .tabItem {
                    Label("Shop".localized, systemImage: "magnifyingglass")
                }
                .tag(2)

            FamilyMainScreen()
                .tabItem {
                    Label("Group".localized, systemImage: "person.3")
                }
                .tag(3)

            PFMView()
                .tabItem {
                    Label("My Plan".localized, systemImage: "list.bullet.clipboard")
                }
                .tag(4)
                .badge(routeService.activePlanCount)
        }
        .accentColor(.blue)
        .onReceive(tabSwitchPub) { _ in
            selection = 4
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                RouteCacheService.shared.refreshHistory()
            }
        }
    }
}
