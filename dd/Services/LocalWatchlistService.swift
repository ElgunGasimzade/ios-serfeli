import Foundation
import Combine
import SwiftUI

class LocalWatchlistService: ObservableObject {
    static let shared = LocalWatchlistService()
    
    @Published var savedItems: [WatchlistItem] = []
    private let key = "watchlist_items"
    
    private init() {
        loadItems()
    }
    
    func loadItems() {
        if let data = UserDefaults.standard.data(forKey: key),
           let items = try? JSONDecoder().decode([WatchlistItem].self, from: data) {
            self.savedItems = items
        }
    }
    
    func saveItem(name: String) {
        // Prevent duplicates by name
        guard !savedItems.contains(where: { $0.name.lowercased() == name.lowercased() }) else { return }
        
        let newItem = WatchlistItem(
            id: UUID().uuidString, // Unique ID for the list item
            name: name,
            status: "Watching prices...",
            subtitle: "Checking deals...",
            badge: nil,
            iconType: "tag.fill"
        )
        
        // Append to local list
        savedItems.insert(newItem, at: 0)
        persistItems()
    }
    
    func updateItemStatus(id: String, status: String, subtitle: String, badge: String?) {
        if let index = savedItems.firstIndex(where: { $0.id == id }) {
            let oldItem = savedItems[index]
            let newItem = WatchlistItem(
                id: oldItem.id,
                name: oldItem.name,
                status: status,
                subtitle: subtitle,
                badge: badge,
                iconType: oldItem.iconType
            )
            savedItems[index] = newItem
            persistItems()
        }
    }
    
    func removeItem(_ id: String) {
        savedItems.removeAll(where: { $0.id == id })
        persistItems()
    }
    
    func removeItemByName(_ name: String) {
        savedItems.removeAll(where: { $0.name.lowercased() == name.lowercased() })
        persistItems()
    }
    
    func isItemSaved(name: String) -> Bool {
        return savedItems.contains(where: { $0.name.lowercased() == name.lowercased() })
    }
    
    private func persistItems() {
        if let data = try? JSONEncoder().encode(savedItems) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
