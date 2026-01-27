import SwiftUI

@main
struct ddApp: App {
    @StateObject private var localization = LocalizationManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(localization)
                .onAppear {
                    // Trigger Guest Login / Init
                    _ = AuthService.shared
                }
        }
    }
}
