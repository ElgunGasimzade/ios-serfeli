import Foundation
import Security

class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}
    
    func save(_ value: String, key: String) {
        let data = Data(value.utf8)
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data
        ] as [String: Any]
        
        SecItemDelete(query as CFDictionary) // Delete existing first
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func get(key: String) -> String? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as [String: Any]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    func delete(key: String) {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key
        ] as [String: Any]
        SecItemDelete(query as CFDictionary)
    }
}
