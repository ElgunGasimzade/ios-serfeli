import SwiftUI
import AppTrackingTransparency

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
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        ATTrackingManager.requestTrackingAuthorization { _ in
                            // No behavior changes required on acceptance/rejection as requested
                        }
                    }
                }
        }
    }
}
