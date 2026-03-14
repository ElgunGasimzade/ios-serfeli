import SwiftUI
import AppTrackingTransparency

#if canImport(FirebaseCore)
import FirebaseCore
import FirebaseMessaging
#endif

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        Messaging.messaging().delegate = NotificationManager.shared
        #endif
        
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        
        return true
    }
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        #if canImport(FirebaseCore)
        Messaging.messaging().apnsToken = deviceToken
        print("DEBUG: Successfully registered with APNs. Token: \(deviceToken)")
        #endif
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("DEBUG: ❌ Failed to register for APNs: \(error.localizedDescription)")
    }
}

@main
struct ddApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var localization = LocalizationManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(localization)
                .onAppear {
                    // Trigger Guest Login / Init
                    _ = AuthService.shared
                    
                    // Request Push Notification permissions
                    NotificationManager.shared.requestPermission()
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
