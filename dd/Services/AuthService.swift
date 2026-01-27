import Foundation
import UIKit
import Combine

// User and AuthResponse moved to ApiModels.swift

class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var user: User?
    private let userKey = "current_user"
    
    // Store userId in UserDefaults for easy access
    var userId: String? {
        user?.id
    }
    
    private init() {
        // Load user from disk if exists
        if let data = UserDefaults.standard.data(forKey: userKey),
           let savedUser = try? JSONDecoder().decode(User.self, from: data) {
            self.user = savedUser
        } else {
             // If no user, trigger login
             login()
        }
    }
    
    func login() {
        // Try getting from Keychain first
        var deviceId = KeychainHelper.shared.get(key: "device_id")
        
        if deviceId == nil || deviceId?.isEmpty == true {
            // Check legacy method (if user updated app) or generate new
            // We can try identifierForVendor, if nil, generic UUID
            let newId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            KeychainHelper.shared.save(newId, key: "device_id")
            deviceId = newId
        }
        
        guard let finalDeviceId = deviceId, !finalDeviceId.isEmpty else { 
            print("Critical Error: Failed to generate Device ID")
            return 
        }
        
        Task {
            do {
                let response = try await APIService.shared.deviceLogin(deviceId: finalDeviceId)
                DispatchQueue.main.async {
                    if let user = response.user {
                        self.user = user
                        self.saveUser(user)
                    }
                }
            } catch {
                print("Login Failed: \(error)")
            }
        }
    }
    
    func updateProfile(email: String?, phone: String?, username: String?) {
        guard let uid = userId else { return }
        
        Task {
            do {
                let response = try await APIService.shared.updateProfile(userId: uid, email: email, phone: phone, username: username)
                 DispatchQueue.main.async {
                    if let updatedUser = response.user { // Assuming response wraps user
                        self.user = updatedUser
                        self.saveUser(updatedUser)
                    }
                }
            } catch {
                print("Profile Update Failed: \(error)")
            }
        }
    }
    
    private func saveUser(_ user: User) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
    }
}
