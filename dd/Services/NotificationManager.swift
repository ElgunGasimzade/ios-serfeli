import Foundation
import UIKit
import UserNotifications
import Combine
import os.log

#if canImport(FirebaseCore)
import FirebaseCore
import FirebaseMessaging
#endif

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var fcmToken: String?
    @Published var unreadCount: Int = 0
    
    override private init() {
        super.init()
    }
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                os_log("Push notification permission error: %{public}@", error.localizedDescription)
                return
            }
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    func syncTokenWithBackend() {
        guard let token = fcmToken else { return }
        
        // Wait until AuthService has completed its initial guest login or full login
        guard let userId = AuthService.shared.userId else {
            os_log("Cannot sync FCM token: No user ID yet.")
            return
        }
        
        // Cache Check: Completely disabled for testing. Uploading every single time.
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        
        os_log("Syncing FCM token to backend...")
        Task {
            do {
                print("DEBUG: Registering FCM token for User: \(userId), Device: \(deviceId), Token: \(token)")
                try await APIService.shared.registerFCMToken(userId: userId, deviceId: deviceId, fcmToken: token, platform: "ios")
                
                // Save to cache after successful upload
                // UserDefaults.standard.set(token, forKey: tokenKey)
                // UserDefaults.standard.set(Date(), forKey: dateKey)
                
                os_log("Successfully registered FCM token.")
                print("DEBUG: Backend returned success for token registration")
            } catch {
                os_log("Failed to register FCM token: %{public}@", error.localizedDescription)
                print("DEBUG: Network error registering token: \(error)")
            }
        }
    }
    
    func fetchUnreadCount() {
        Task {
            do {
                let count = try await APIService.shared.getUnreadNotificationCount()
                DispatchQueue.main.async {
                    self.unreadCount = count
                }
            } catch {
                print("Failed to fetch unread notifications count: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        // Show notification even when app is in foreground
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
        os_log("Notification clicked with userInfo: %{public}@", userInfo.description)
        completionHandler()
    }
}

#if canImport(FirebaseCore)
// MARK: - MessagingDelegate
extension NotificationManager: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else { return }
        os_log("Firebase registration token received: %{public}@", fcmToken)
        self.fcmToken = fcmToken
        
        // Synchronize with backend
        syncTokenWithBackend()
    }
}
#endif
