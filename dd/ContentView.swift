import SwiftUI

struct ContentView: View {
    @EnvironmentObject var localization: LocalizationManager
    
    var body: some View {
        TabView {
            HomeScreen()
                .tabItem {
                    Label("Home".localized, systemImage: "house")
                }
            
            ScanCaptureScreen()
                .tabItem {
                    Label("Scan".localized, systemImage: "camera.viewfinder")
                }
            
            // Watchlist
            WatchlistScreen()
                .tabItem {
                    Label("Watchlist".localized, systemImage: "eye")
                }
            
            // Profile
            ProfileScreen()
                .tabItem {
                    Label("Profile".localized, systemImage: "person")
                }
        }
        .accentColor(.blue)
    }
}
