import SwiftUI

struct ContentView: View {
    @EnvironmentObject var localization: LocalizationManager
    @State private var selection = 0
    
    // Listen for tab switching requests
    // Ideally this would be an injected environment object/service, but for speed, 
    // we can use NotificationCenter or a simple SharedState if already existing.
    // Let's use NotificationCenter for simplicity given the constraints.
    let tabSwitchPub = NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToPFM"))
    
    var body: some View {
        TabView(selection: $selection) {
            HomeScreen()
                .tabItem {
                    Label("Home".localized, systemImage: "house")
                }
                .tag(0)
            
            // Watchlist
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
                
            // My Plan (PFM)
            PFMView()
                .tabItem {
                    Label("My Plan".localized, systemImage: "list.bullet.clipboard")
                }
                .tag(3)
            
            // Profile
            ProfileScreen()
                .tabItem {
                    Label("Profile".localized, systemImage: "person")
                }
                .tag(4)
        }
        .accentColor(.blue)
        .onReceive(tabSwitchPub) { _ in
            selection = 3 // Switch to PFM tab
        }
    }
}
